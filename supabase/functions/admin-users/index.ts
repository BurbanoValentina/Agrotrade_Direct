// Edge Function admin-users (REQ-33 / REQ-24).
//
// Operaciones que necesitan la clave service_role (nunca va en la app):
//   create_staff  Invita por correo a un empleado nuevo y le asigna permisos.
//   delete_user   Borra una cuenta de Supabase Auth (y su perfil en cascada).
//
// La app la llama con el token del usuario que inició sesión:
//   supabase.functions.invoke('admin-users', body: {'action': 'create_staff', ...})
// Las reglas de quién puede hacer qué están en rules.ts (con pruebas).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  HttpError,
  parseTargetUserId,
  type StaffRow,
  validateCreateStaff,
  validateDeleteUser,
} from "./rules.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido." }, 405);

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    // Quién llama: se valida su token con Supabase Auth.
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) throw new HttpError(401, "Debes iniciar sesión.");
    const callerId = userData.user.id;
    const caller = await getStaff(admin, callerId);

    const body = await req.json().catch(() => null);
    switch (body?.action) {
      case "create_staff":
        return json(await createStaff(admin, callerId, caller, body));
      case "delete_user":
        return json(await deleteUser(admin, callerId, caller, body));
      default:
        throw new HttpError(400, "Acción no válida: usa create_staff o delete_user.");
    }
  } catch (error) {
    if (error instanceof HttpError) return json({ error: error.message }, error.status);
    console.error("admin-users:", error);
    return json({ error: "Error interno del servidor. Intenta de nuevo." }, 500);
  }
});

async function getStaff(admin: SupabaseClient, userId: string): Promise<StaffRow | null> {
  const { data, error } = await admin
    .from("staff_members")
    .select("user_id, is_super_admin, permissions, is_active")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data as StaffRow | null;
}

async function createStaff(
  admin: SupabaseClient,
  callerId: string,
  caller: StaffRow | null,
  body: unknown,
) {
  const input = validateCreateStaff(caller, body);

  // Un correo que ya es exportador/importador no se convierte en staff: se
  // perderían sus ofertas y negociaciones. El empleado usa otro correo.
  const { data: existing, error: lookupError } = await admin
    .from("profiles")
    .select("id")
    .eq("email", input.email)
    .maybeSingle();
  if (lookupError) throw lookupError;
  if (existing) {
    throw new HttpError(409, "Ese correo ya tiene una cuenta en AgroTrade. Usa otro correo para el empleado.");
  }

  // Invitación: Supabase le envía un enlace que inicia su sesión en la app;
  // must_set_password hace que la app le pida crear su contraseña
  // (AppUser.mustSetPassword → AuthRepository.changePassword).
  const redirectTo = Deno.env.get("STAFF_INVITE_REDIRECT_URL") ?? undefined;
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
    input.email,
    {
      data: { name: input.name ?? input.email.split("@")[0], must_set_password: true },
      redirectTo,
    },
  );
  if (inviteError || !invited.user) {
    throw new HttpError(400, `No se pudo enviar la invitación: ${inviteError?.message ?? "sin detalle"}.`);
  }

  // El trigger de registro ya creó su perfil; al agregarlo a staff_members
  // su rol pasa a 'staff' (trigger mark_profile_as_staff).
  const { error: insertError } = await admin.from("staff_members").insert({
    user_id: invited.user.id,
    permissions: input.permissions,
    is_super_admin: input.isSuperAdmin,
    created_by: callerId,
  });
  if (insertError) {
    // No dejar una cuenta invitada sin permisos.
    await admin.auth.admin.deleteUser(invited.user.id);
    throw new HttpError(400, `No se pudo registrar el empleado: ${insertError.message}`);
  }

  return {
    user_id: invited.user.id,
    email: input.email,
    permissions: input.permissions,
    is_super_admin: input.isSuperAdmin,
    invited: true,
  };
}

async function deleteUser(
  admin: SupabaseClient,
  callerId: string,
  caller: StaffRow | null,
  body: unknown,
) {
  const targetId = parseTargetUserId(body);
  const targetStaff = await getStaff(admin, targetId);

  const { count, error: countError } = await admin
    .from("negotiations")
    .select("id", { count: "exact", head: true })
    .eq("status", "confirmed")
    .or(`buyer_id.eq.${targetId},seller_id.eq.${targetId}`);
  if (countError) throw countError;

  validateDeleteUser({ callerId, caller, targetId, targetStaff, confirmedDeals: count ?? 0 });

  // Los PDF de certificados no se borran en cascada: se limpian aquí.
  const { data: files } = await admin.storage.from("certifications").list(targetId);
  if (files && files.length > 0) {
    await admin.storage.from("certifications").remove(files.map((f) => `${targetId}/${f.name}`));
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(targetId);
  if (deleteError) {
    throw new HttpError(400, `No se pudo borrar la cuenta: ${deleteError.message}`);
  }
  return { deleted: true, user_id: targetId };
}
