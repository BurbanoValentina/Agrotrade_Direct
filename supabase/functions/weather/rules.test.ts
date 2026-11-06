// Pruebas de las reglas de la Edge Function weather.
// Ejecutar desde la raíz del proyecto:  node --test supabase/functions/weather/rules.test.ts
import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
  canRunWeatherCheck,
  DAILY_FIELDS,
  HttpError,
  isCronRequest,
  isFresh,
  openMeteoUrl,
  parseRegionId,
  validateForecast,
} from "./rules.ts";

const forecast = (days = 2) => ({
  daily: Object.fromEntries([
    ["time", Array.from({ length: days }, (_, i) => `2026-11-0${6 + i}`)],
    ...DAILY_FIELDS.map((f) => [f, Array(days).fill(1)]),
  ]),
});

describe("openMeteoUrl", () => {
  test("pide los datos diarios en hora de Colombia, sin llave", () => {
    const url = new URL(openMeteoUrl(1.8537, -76.0507));
    assert.equal(url.host, "api.open-meteo.com");
    assert.equal(url.searchParams.get("latitude"), "1.8537");
    assert.equal(url.searchParams.get("timezone"), "America/Bogota");
    assert.match(url.searchParams.get("daily")!, /precipitation_sum/);
    assert.equal(url.searchParams.has("apikey"), false);
  });
});

describe("isFresh", () => {
  const now = new Date("2026-11-06T12:00:00Z");
  test("sirve un pronóstico de hace 1 hora", () => {
    assert.equal(isFresh("2026-11-06T11:00:00Z", now), true);
  });
  test("vence a las 3 horas", () => {
    assert.equal(isFresh("2026-11-06T09:00:00Z", now), false);
  });
  test("sin fecha o fecha inválida no sirve", () => {
    assert.equal(isFresh(null, now), false);
    assert.equal(isFresh("ayer", now), false);
  });
});

describe("parseRegionId", () => {
  test("acepta ids de región", () => {
    assert.equal(parseRegionId({ region_id: "sierra_nevada" }), "sierra_nevada");
  });
  test("rechaza vacío, mayúsculas o caracteres raros", () => {
    for (const body of [null, {}, { region_id: "" }, { region_id: "Huila" }, { region_id: "huila;drop" }]) {
      assert.throws(() => parseRegionId(body), (e: unknown) => e instanceof HttpError && e.status === 400);
    }
  });
});

describe("validateForecast", () => {
  test("acepta la respuesta completa", () => {
    assert.doesNotThrow(() => validateForecast(forecast()));
  });
  test("rechaza respuestas sin días o con columnas incompletas", () => {
    const broken = forecast();
    (broken.daily as Record<string, unknown>).precipitation_sum = [1];
    for (const json of [null, { error: true }, { daily: { time: [] } }, broken]) {
      assert.throws(() => validateForecast(json), (e: unknown) => e instanceof HttpError && e.status === 502);
    }
  });
});

describe("canRunWeatherCheck", () => {
  const staff = { is_super_admin: false, permissions: ["settings"], is_active: true };
  test("personal con settings o super admin", () => {
    assert.equal(canRunWeatherCheck(staff), true);
    assert.equal(canRunWeatherCheck({ ...staff, permissions: [], is_super_admin: true }), true);
  });
  test("ni usuarios normales, ni otros permisos, ni inactivos, ni gerentes", () => {
    assert.equal(canRunWeatherCheck(null), false);
    assert.equal(canRunWeatherCheck({ ...staff, permissions: ["security"] }), false);
    assert.equal(canRunWeatherCheck({ ...staff, is_active: false }), false);
    assert.equal(canRunWeatherCheck({ ...staff, is_manager: true, permissions: [] }), false);
  });
});

describe("isCronRequest", () => {
  test("solo con el secreto exacto", () => {
    assert.equal(isCronRequest("s3cr3t-largo", "s3cr3t-largo"), true);
    assert.equal(isCronRequest("s3cr3t-larga", "s3cr3t-largo"), false);
    assert.equal(isCronRequest(null, "s3cr3t-largo"), false);
  });
  test("sin CRON_SECRET configurado nunca se acepta", () => {
    assert.equal(isCronRequest("", ""), false);
    assert.equal(isCronRequest("algo", undefined), false);
  });
});
