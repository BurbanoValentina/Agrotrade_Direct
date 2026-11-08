-- ==============================================================================
-- REQ-48 / REQ-49: regiones de clima, caché del pronóstico y alertas climáticas.
-- ==============================================================================
-- E = exportador en Huila, E2 = exportador en Nariño, I = importador con
-- solicitud en curso, J = importador con un envío ya entregado, S = settings.
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('55555555-5555-5555-5555-555555555555','e2@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','j@x.com','{"role":"importador"}'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','set@x.com','{}');
INSERT INTO staff_members (user_id, permissions) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','{settings}');

CREATE FUNCTION pg_temp.check(label text, cond text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE ok boolean;
BEGIN EXECUTE 'SELECT ' || cond INTO ok; RETURN CASE WHEN ok THEN 'OK    ' ELSE 'FALLO ' END || label; END $$;
CREATE FUNCTION pg_temp.n(u uuid, title_like text) RETURNS bigint LANGUAGE sql SECURITY DEFINER AS
  $$ SELECT count(*) FROM notifications WHERE user_id = u AND title LIKE title_like $$;
-- Respuesta con la forma de Open-Meteo, días desde el 06/11/2026.
CREATE FUNCTION pg_temp.fc(rain numeric[], tmin numeric[], tmax numeric[], wind numeric[]) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('latitude', 1.85, 'longitude', -76.05, 'daily', jsonb_build_object(
    'time', (SELECT jsonb_agg(to_char(date '2026-11-06' + g, 'YYYY-MM-DD') ORDER BY g)
             FROM generate_series(0, array_length(rain, 1) - 1) g),
    'precipitation_sum', to_jsonb(rain), 'temperature_2m_min', to_jsonb(tmin),
    'temperature_2m_max', to_jsonb(tmax), 'wind_speed_10m_max', to_jsonb(wind)))
$$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated, service_role;

\set E '''11111111-1111-1111-1111-111111111111'''
\set E2 '''55555555-5555-5555-5555-555555555555'''
\set I '''22222222-2222-2222-2222-222222222222'''
\set J '''33333333-3333-3333-3333-333333333333'''

\echo '== Asociar la región de origen de una oferta'
SELECT pg_temp.check('"Huila" -> huila', $$weather_region_for('Huila') = 'huila'$$);
SELECT pg_temp.check('"Narino" y "Nariño" -> narino', $$weather_region_for('Narino') = 'narino' AND weather_region_for(' nariño ') = 'narino'$$);
SELECT pg_temp.check('"Eje Cafetero" -> quindio', $$weather_region_for('Eje Cafetero') = 'quindio'$$);
SELECT pg_temp.check('"Sierra Nevada" -> sierra_nevada', $$weather_region_for('Sierra Nevada') = 'sierra_nevada'$$);
SELECT pg_temp.check('"Huila - Pitalito" -> huila', $$weather_region_for('Huila - Pitalito') = 'huila'$$);
SELECT pg_temp.check('"Tumaco" -> tumaco (no Nariño)', $$weather_region_for('Tumaco') = 'tumaco'$$);
SELECT pg_temp.check('Lugar desconocido -> sin región', $$weather_region_for('Bogotá') IS NULL$$);

\echo '== Datos de prueba: ofertas y tratos'
SET ROLE authenticated;
SELECT pg_temp.as_user(:E) \gset x
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country)
VALUES ('f0000000-0000-0000-0000-000000000001', auth.uid(), 'cafe', 'Geisha', 'Huila', 8400, 20, 'Alemania');
SELECT pg_temp.as_user(:E2) \gset x
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country)
VALUES ('f0000000-0000-0000-0000-000000000002', auth.uid(), 'cafe', 'Castillo', 'Nariño', 7000, 10, 'España');
SELECT pg_temp.as_user(:J) \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES ('a0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', auth.uid(), 8300, 5);
SELECT pg_temp.as_user(:E) \gset x
SELECT accept_negotiation('a0000000-0000-0000-0000-000000000002') \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000002') \gset x
SELECT pg_temp.as_user(:J) \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000002') \gset x
SELECT pg_temp.as_user(:E) \gset x
SELECT update_shipping_status('a0000000-0000-0000-0000-000000000002', 'embarcado') \gset x
SELECT pg_temp.as_user(:J) \gset x
SELECT update_shipping_status('a0000000-0000-0000-0000-000000000002', 'entregado') \gset x
SELECT pg_temp.as_user(:I) \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', auth.uid(), 8000, 10);

\echo '== Permisos'
SELECT pg_temp.t('I ve las regiones de clima', $$SELECT 1 FROM weather_regions WHERE id = 'huila'$$, true);
SELECT pg_temp.t('I agrega una región', $$INSERT INTO weather_regions (id, name, department, latitude, longitude) VALUES ('meta', 'Meta', 'Meta', 4.1, -73.6)$$, false);
SELECT pg_temp.t('I llama ingest_weather_forecast', $$SELECT ingest_weather_forecast('huila', '{"daily":{"time":[]}}')$$, false);
SELECT pg_temp.t('I crea una alerta a mano', $$INSERT INTO weather_alerts (region_id, alert_date, kind, value, threshold, message) VALUES ('huila', '2026-11-06', 'helada', 0, 2, 'x')$$, false);
SELECT pg_temp.t('I escribe en la caché del pronóstico', $$INSERT INTO weather_forecasts (region_id, forecast) VALUES ('huila', '{}')$$, false);
SELECT pg_temp.t('I cambia el umbral de lluvia', $$UPDATE platform_config SET weather_rain_mm = 1$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Settings agrega una región', $$INSERT INTO weather_regions (id, name, department, latitude, longitude) VALUES ('meta', 'Meta', 'Meta', 4.1, -73.6)$$, true);
SELECT pg_temp.t('Settings ajusta el umbral de lluvia (y lo restaura)', $$UPDATE platform_config SET weather_rain_mm = 55$$, true);
UPDATE platform_config SET weather_rain_mm = 50;
RESET ROLE;
SELECT pg_temp.check('Regiones a revisar: Huila y Nariño (con actividad), no Cauca',
  $$(SELECT array_agg(id ORDER BY id) = ARRAY['huila','narino'] FROM weather_regions_with_activity())$$);

\echo '== Pronóstico y alertas (Edge Function = service_role)'
SET ROLE service_role;
SELECT pg_temp.t('Pronóstico tranquilo de Huila', $$SELECT ingest_weather_forecast('huila', pg_temp.fc(ARRAY[5,10,0], ARRAY[14,15,13], ARRAY[26,27,25], ARRAY[15,20,18]))$$, true);
RESET ROLE;
SELECT pg_temp.check('Queda en caché y sin alertas', $$(SELECT count(*) = 1 FROM weather_forecasts WHERE region_id = 'huila') AND NOT EXISTS (SELECT 1 FROM weather_alerts)$$);

SET ROLE service_role;
-- Día 1 lluvia 80 mm, día 2 máxima 36 °C, día 3 viento 70 km/h, día 4 lluvia 120 mm (fuera de la ventana de 3 días).
SELECT pg_temp.t('Pronóstico con tormenta en Huila', $$SELECT ingest_weather_forecast('huila', pg_temp.fc(ARRAY[80,10,0,120], ARRAY[14,15,13,14], ARRAY[26,36,25,26], ARRAY[15,20,70,10]))$$, true);
RESET ROLE;
SELECT pg_temp.check('Se crean 3 alertas (lluvia, calor, viento)', $$(SELECT array_agg(kind ORDER BY alert_date) = ARRAY['lluvia_fuerte','calor_extremo','viento_fuerte'] FROM weather_alerts)$$);
SELECT pg_temp.check('El día 4 (fuera de la ventana) no genera alerta', $$NOT EXISTS (SELECT 1 FROM weather_alerts WHERE alert_date = '2026-11-09')$$);
SELECT pg_temp.check('Mensaje con región, fecha y valor',
  $$(SELECT message LIKE 'Lluvia fuerte en Huila el 06/11: 80 mm previstos.%' FROM weather_alerts WHERE kind = 'lluvia_fuerte')$$);
SELECT pg_temp.check('E (oferta en Huila) recibe la alerta de lluvia', format('pg_temp.n(%L, %L) = 1', :E, 'Alerta de lluvia fuerte'));
SELECT pg_temp.check('I (solicitud en curso) recibe la alerta de lluvia', format('pg_temp.n(%L, %L) = 1', :I, 'Alerta de lluvia fuerte'));
SELECT pg_temp.check('J (envío ya entregado) no recibe alertas', format('pg_temp.n(%L, %L) = 0', :J, 'Alerta de%'));
SELECT pg_temp.check('E2 (Nariño) no recibe alertas de Huila', format('pg_temp.n(%L, %L) = 0', :E2, 'Alerta de%'));
SELECT pg_temp.check('La alerta registra a cuántos avisó (2)', $$(SELECT notified_count = 2 FROM weather_alerts WHERE kind = 'lluvia_fuerte')$$);

SET ROLE service_role;
SELECT pg_temp.t('Mismo pronóstico otra vez', $$SELECT ingest_weather_forecast('huila', pg_temp.fc(ARRAY[80,10,0,120], ARRAY[14,15,13,14], ARRAY[26,36,25,26], ARRAY[15,20,70,10]))$$, true);
RESET ROLE;
SELECT pg_temp.check('No duplica alertas ni avisos', format($$(SELECT count(*) = 3 FROM weather_alerts) AND pg_temp.n(%L, 'Alerta de lluvia fuerte') = 1$$, :E));

SET ROLE authenticated;
SELECT pg_temp.as_user(:I) \gset x
INSERT INTO alert_preferences (user_id, weather_alerts) VALUES (auth.uid(), false);
SELECT pg_temp.t('I ve las alertas de clima publicadas', $$SELECT 1 FROM weather_alerts WHERE region_id = 'huila'$$, true);
SELECT pg_temp.t('I ve el pronóstico en caché', $$SELECT forecast FROM weather_forecasts WHERE region_id = 'huila'$$, true);
SET ROLE service_role;
SELECT pg_temp.t('Helada en Huila', $$SELECT ingest_weather_forecast('huila', pg_temp.fc(ARRAY[0], ARRAY[1], ARRAY[18], ARRAY[10]))$$, true);
RESET ROLE;
SELECT pg_temp.check('Con alertas de clima apagadas, I no recibe la helada', format('pg_temp.n(%L, %L) = 0', :I, 'Alerta de helada'));
SELECT pg_temp.check('E sí recibe la helada', format('pg_temp.n(%L, %L) = 1', :E, 'Alerta de helada'));

SET ROLE service_role;
SELECT pg_temp.t('Región inexistente', $$SELECT ingest_weather_forecast('marte', pg_temp.fc(ARRAY[0], ARRAY[1], ARRAY[18], ARRAY[10]))$$, false);
SELECT pg_temp.t('Respuesta sin datos diarios', $$SELECT ingest_weather_forecast('huila', '{"error": true}')$$, false);
RESET ROLE;
