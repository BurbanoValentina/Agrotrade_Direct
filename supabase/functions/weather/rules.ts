// Reglas de la Edge Function weather (REQ-48 / REQ-49).
//
// Sin dependencias de Deno ni de Supabase, para poder probarlas con Node:
//   node --test supabase/functions/weather/rules.test.ts

/** Minutos que se reutiliza un pronóstico guardado antes de pedir uno nuevo. */
export const FORECAST_TTL_MINUTES = 180;

/** Días de pronóstico que se piden a Open-Meteo. */
export const FORECAST_DAYS = 7;

export const DAILY_FIELDS = [
  "weather_code",
  "temperature_2m_max",
  "temperature_2m_min",
  "precipitation_sum",
  "wind_speed_10m_max",
] as const;

/** Error con código HTTP y mensaje para el usuario (en español). */
export class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

/** Fila de public.staff_members (solo lo necesario). */
export interface StaffRow {
  is_super_admin: boolean;
  permissions: string[];
  is_active: boolean;
  is_manager?: boolean;
}

/** URL de Open-Meteo para unas coordenadas (gratis, sin llave). */
export function openMeteoUrl(latitude: number, longitude: number): string {
  const params = new URLSearchParams({
    latitude: String(latitude),
    longitude: String(longitude),
    daily: DAILY_FIELDS.join(","),
    timezone: "America/Bogota",
    forecast_days: String(FORECAST_DAYS),
  });
  return `https://api.open-meteo.com/v1/forecast?${params}`;
}

/** Si un pronóstico guardado en [fetchedAt] todavía sirve en [now]. */
export function isFresh(
  fetchedAt: string | null | undefined,
  now: Date,
  ttlMinutes = FORECAST_TTL_MINUTES,
): boolean {
  if (!fetchedAt) return false;
  const time = Date.parse(fetchedAt);
  if (Number.isNaN(time)) return false;
  const ageMs = now.getTime() - time;
  return ageMs >= 0 && ageMs < ttlMinutes * 60_000;
}

/** Lee region_id del cuerpo de la petición: 'huila', 'sierra_nevada', ... */
export function parseRegionId(body: unknown): string {
  const value = (body as { region_id?: unknown } | null)?.region_id;
  if (typeof value !== "string" || !/^[a-z0-9_]{2,40}$/.test(value.trim())) {
    throw new HttpError(400, "Indica la región (region_id), por ejemplo 'huila'.");
  }
  return value.trim();
}

/** Valida que la respuesta de Open-Meteo traiga los datos diarios. */
export function validateForecast(json: unknown): Record<string, unknown> {
  const daily = (json as { daily?: Record<string, unknown> } | null)?.daily;
  const time = daily?.time;
  if (!Array.isArray(time) || time.length === 0) {
    throw new HttpError(502, "El servicio del clima no respondió bien. Intenta más tarde.");
  }
  for (const field of DAILY_FIELDS) {
    const values = daily?.[field];
    if (!Array.isArray(values) || values.length !== time.length) {
      throw new HttpError(502, "El servicio del clima no respondió bien. Intenta más tarde.");
    }
  }
  return json as Record<string, unknown>;
}

/**
 * Quién puede lanzar la revisión de alertas a mano: personal activo con el
 * permiso settings (o super admin). El gerente es solo consulta (REQ-46).
 */
export function canRunWeatherCheck(staff: StaffRow | null): boolean {
  if (!staff || !staff.is_active || staff.is_manager) return false;
  return staff.is_super_admin || staff.permissions.includes("settings");
}

/**
 * Llamada programada (pg_cron): el encabezado x-cron-secret debe coincidir con
 * el secreto CRON_SECRET. Sin secreto configurado, nunca se acepta.
 */
export function isCronRequest(header: string | null, secret: string | undefined): boolean {
  if (!secret || !header || header.length !== secret.length) return false;
  let diff = 0;
  for (let i = 0; i < secret.length; i++) {
    diff |= header.charCodeAt(i) ^ secret.charCodeAt(i);
  }
  return diff === 0;
}
