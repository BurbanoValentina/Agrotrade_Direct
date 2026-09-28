// Reglas de autorización y validación de la Edge Function admin-users.
//
// Sin dependencias de Deno ni de Supabase, para poder probarlas con Node:
//   node --test supabase/functions/admin-users/rules.test.ts
// Replican las reglas de la BD (migración 20260925020000_rbac_staff.sql,
// función enforce_staff_rules), porque la función usa la clave service_role y
// esas reglas no se aplican automáticamente.

/** Mismos valores que el enum AdminPermission de Flutter y el CHECK de la BD. */
export const ADMIN_PERMISSIONS = [
  "dashboard",
  "userManagement",
  "employeeManagement",
  "offerManagement",
  "negotiationManagement",
  "reports",
  "settings",
  "security",
] as const;

export type AdminPermission = (typeof ADMIN_PERMISSIONS)[number];

/** Fila de public.staff_members. */
export interface StaffRow {
  user_id: string;
  is_super_admin: boolean;
  permissions: string[];
  is_active: boolean;
}

/** Error con código HTTP y mensaje para el usuario (en español). */
export class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function hasPermission(staff: StaffRow | null, permission: AdminPermission): boolean {
  if (!staff || !staff.is_active) return false;
  return staff.is_super_admin || staff.permissions.includes(permission);
}

export interface CreateStaffInput {
  email: string;
  name: string | null;
  permissions: AdminPermission[];
  isSuperAdmin: boolean;
}

/**
 * Valida la creación de un empleado:
 *  - quien llama necesita employeeManagement;
 *  - solo un super admin crea otro super admin;
 *  - un admin normal solo otorga permisos que él mismo tiene.
 */
export function validateCreateStaff(caller: StaffRow | null, body: unknown): CreateStaffInput {
  if (!hasPermission(caller, "employeeManagement")) {
    throw new HttpError(403, "Requiere el permiso employeeManagement.");
  }
  const input = (body ?? {}) as Record<string, unknown>;

  const email = typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
  if (!EMAIL_RE.test(email)) {
    throw new HttpError(400, "El correo del empleado no es válido.");
  }

  const rawName = typeof input.name === "string" ? input.name.trim() : "";
  if (rawName.length > 80) {
    throw new HttpError(400, "El nombre es demasiado largo (máximo 80 caracteres).");
  }

  const rawPermissions = input.permissions ?? [];
  if (!Array.isArray(rawPermissions) || rawPermissions.some((p) => typeof p !== "string")) {
    throw new HttpError(400, "permissions debe ser una lista de permisos.");
  }
  const unknown = rawPermissions.filter(
    (p) => !(ADMIN_PERMISSIONS as readonly string[]).includes(p as string),
  );
  if (unknown.length > 0) {
    throw new HttpError(400, `Permisos no válidos: ${unknown.join(", ")}.`);
  }
  const permissions = [...new Set(rawPermissions as AdminPermission[])];
  const isSuperAdmin = input.is_super_admin === true;

  if (!caller!.is_super_admin) {
    if (isSuperAdmin) {
      throw new HttpError(403, "Solo un super admin puede crear otro super admin.");
    }
    const notOwned = permissions.filter((p) => !caller!.permissions.includes(p));
    if (notOwned.length > 0) {
      throw new HttpError(403, `No puedes otorgar permisos que no tienes: ${notOwned.join(", ")}.`);
    }
  }
  if (!isSuperAdmin && permissions.length === 0) {
    throw new HttpError(400, "Asigna al menos un permiso al empleado.");
  }

  return { email, name: rawName || null, permissions, isSuperAdmin };
}

/** Extrae y valida el id del usuario a borrar (evita inyección en filtros). */
export function parseTargetUserId(body: unknown): string {
  const userId = (body as Record<string, unknown> | null)?.user_id;
  if (typeof userId !== "string" || !UUID_RE.test(userId)) {
    throw new HttpError(400, "user_id no es un identificador válido.");
  }
  return userId.toLowerCase();
}

/**
 * Valida el borrado de una cuenta:
 *  - quien llama necesita userManagement (y employeeManagement si borra staff);
 *  - nadie borra su propia cuenta; solo un super admin borra a otro;
 *  - no se borran cuentas con tratos confirmados (se perdería el historial de
 *    la contraparte): se deben bloquear.
 */
export function validateDeleteUser(params: {
  callerId: string;
  caller: StaffRow | null;
  targetId: string;
  targetStaff: StaffRow | null;
  confirmedDeals: number;
}): void {
  const { callerId, caller, targetId, targetStaff, confirmedDeals } = params;
  if (!hasPermission(caller, "userManagement")) {
    throw new HttpError(403, "Requiere el permiso userManagement.");
  }
  if (targetId === callerId.toLowerCase()) {
    throw new HttpError(400, "No puedes borrar tu propia cuenta.");
  }
  if (targetStaff) {
    if (!hasPermission(caller, "employeeManagement")) {
      throw new HttpError(403, "Para borrar a un empleado se requiere employeeManagement.");
    }
    if (targetStaff.is_super_admin && !caller!.is_super_admin) {
      throw new HttpError(403, "Solo un super admin puede borrar a otro super admin.");
    }
  }
  if (confirmedDeals > 0) {
    throw new HttpError(
      409,
      `El usuario tiene ${confirmedDeals} trato(s) confirmado(s) que forman parte del historial. ` +
        "Bloquéalo en lugar de borrarlo.",
    );
  }
}
