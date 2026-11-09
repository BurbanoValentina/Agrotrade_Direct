// Edge Function weather (REQ-48 / REQ-49).
//
// La app nunca llama a la API del clima directamente: pasa por aquí, para
// guardar el pronóstico en caché y generar las alertas. Hoy se usa Open-Meteo
// (gratis, sin llave); si se cambia a una API con llave, la llave va en los
// secretos de Supabase (supabase secrets set ...) y la app no cambia.
//
//   forecast      Pronóstico de 7 días de una región (cualquier usuario con sesión).
//                 body: {'action': 'forecast', 'region_id': 'huila'}
//   check_alerts  Revisa todas las regiones con ofertas o tratos en curso y
//                 envía las alertas. Lo usa la tarea programada (encabezado
//                 x-cron-secret = secreto CRON_SECRET) o el personal con permiso
//                 settings desde el panel.
//
// Las reglas están en rules.ts (con pruebas); los umbrales y a quién se avisa,
// en la migración 20261105040000_weather_alerts.sql (ingest_weather_forecast).
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  canRunWeatherCheck,
  HttpError,
  isCronRequest,
  isFresh,
  openMeteoUrl,
  parseRegionId,
  type StaffRow,
  validateForecast,
} from "./rules.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
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
    const body = await req.json().catch(() => null);

    switch (body?.action) {
      case "forecast": {
        await requireUser(admin, req);
        return json(await getForecast(admin, parseRegionId(body)));
      }
      case "check_alerts": {
        if (!isCronRequest(req.headers.get("x-cron-secret"), Deno.env.get("CRON_SECRET"))) {
          const userId = await requireUser(admin, req);
          if (!canRunWeatherCheck(await getStaff(admin, userId))) {
            throw new HttpError(403, "Solo el personal con permiso de configuración puede revisar las alertas.");
          }
        }
        return json(await checkAlerts(admin));
      }
      default:
        throw new HttpError(400, "Acción no válida: usa forecast o check_alerts.");
    }
  } catch (error) {
    if (error instanceof HttpError) return json({ error: error.message }, error.status);
    console.error("weather:", error);
    return json({ error: "Error interno del servidor. Intenta de nuevo." }, 500);
  }
});

async function requireUser(admin: SupabaseClient, req: Request): Promise<string> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Debes iniciar sesión.");
  return data.user.id;
}

async function getStaff(admin: SupabaseClient, userId: string): Promise<StaffRow | null> {
  const { data, error } = await admin
    .from("staff_members")
    .select("is_super_admin, permissions, is_active, is_manager")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data as StaffRow | null;
}

interface Region {
  id: string;
  name: string;
  department: string;
  latitude: number;
  longitude: number;
}

/**
 * Pronóstico de la región: usa la caché si tiene menos de 3 horas; si no, lo
 * pide a Open-Meteo y lo guarda con ingest_weather_forecast (que además crea
 * las alertas). Si Open-Meteo falla, devuelve la última copia marcada `stale`.
 */
async function getForecast(admin: SupabaseClient, regionId: string) {
  const { data: region, error: regionError } = await admin
    .from("weather_regions")
    .select("id, name, department, latitude, longitude")
    .eq("id", regionId)
    .maybeSingle();
  if (regionError) throw regionError;
  if (!region) throw new HttpError(404, "Esa región no existe.");

  const { data: cached, error: cacheError } = await admin
    .from("weather_forecasts")
    .select("forecast, fetched_at")
    .eq("region_id", regionId)
    .maybeSingle();
  if (cacheError) throw cacheError;

  if (cached && isFresh(cached.fetched_at, new Date())) {
    return { region, forecast: cached.forecast, fetched_at: cached.fetched_at, cached: true, stale: false };
  }

  let forecast: Record<string, unknown>;
  try {
    const r = region as Region;
    const response = await fetch(openMeteoUrl(r.latitude, r.longitude));
    if (!response.ok) throw new HttpError(502, "El servicio del clima no respondió bien. Intenta más tarde.");
    forecast = validateForecast(await response.json());
  } catch (error) {
    if (cached) {
      return { region, forecast: cached.forecast, fetched_at: cached.fetched_at, cached: true, stale: true };
    }
    if (error instanceof HttpError) throw error;
    throw new HttpError(502, "No pudimos consultar el clima. Revisa tu conexión e intenta más tarde.");
  }

  const { data: summary, error: ingestError } = await admin.rpc("ingest_weather_forecast", {
    p_region_id: regionId,
    p_forecast: forecast,
  });
  if (ingestError) throw ingestError;

  return {
    region,
    forecast,
    fetched_at: new Date().toISOString(),
    cached: false,
    stale: false,
    alerts: summary,
  };
}

async function checkAlerts(admin: SupabaseClient) {
  const { data: regions, error } = await admin.rpc("weather_regions_with_activity");
  if (error) throw error;

  let alertsCreated = 0;
  let notified = 0;
  const errors: { region_id: string; error: string }[] = [];

  for (const region of (regions ?? []) as Region[]) {
    try {
      const result = await getForecast(admin, region.id);
      const summary = (result as { alerts?: { alerts_created?: number; notified?: number } }).alerts;
      alertsCreated += summary?.alerts_created ?? 0;
      notified += summary?.notified ?? 0;
    } catch (e) {
      errors.push({ region_id: region.id, error: e instanceof Error ? e.message : String(e) });
    }
  }

  return {
    regions_checked: (regions ?? []).length,
    alerts_created: alertsCreated,
    notified,
    errors,
  };
}
