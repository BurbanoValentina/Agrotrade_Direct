-- ==============================================================================
-- Clima y alertas climáticas (REQ-48, REQ-49; decisiones D5 y D6)
-- ==============================================================================
-- API: Open-Meteo (gratis, sin llave). La app NO la llama directo: usa la Edge
-- Function `weather` (supabase/functions/weather), que guarda el pronóstico en
-- caché y genera las alertas. Si se cambia a una API con llave, la llave va en
-- los secretos de Supabase y la app no cambia.
--
-- * weather_regions: zonas productoras de café/cacao con coordenadas. Las
--   ofertas se asocian por su origin_region (nombre o alias, sin tildes).
-- * weather_forecasts: último pronóstico por región (caché de la Edge Function).
-- * weather_alerts: alertas generadas (una por región, día y tipo).
-- * platform_config: umbrales de alerta, editables con el permiso settings.
-- * ingest_weather_forecast(): guarda el pronóstico, evalúa los próximos días
--   y avisa (notifications tipo 'clima') a exportadores con ofertas de la
--   región y a las partes de tratos en curso o envíos sin entregar.
--   Solo la ejecuta la Edge Function (service_role).
-- ==============================================================================

-- ==============================================================================
-- 1. UMBRALES (platform_config)
-- ==============================================================================
ALTER TABLE public.platform_config
  ADD COLUMN IF NOT EXISTS weather_rain_mm NUMERIC(6, 1) NOT NULL DEFAULT 50 CHECK (weather_rain_mm > 0),
  ADD COLUMN IF NOT EXISTS weather_frost_c NUMERIC(4, 1) NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS weather_heat_c NUMERIC(4, 1) NOT NULL DEFAULT 35,
  ADD COLUMN IF NOT EXISTS weather_wind_kmh NUMERIC(5, 1) NOT NULL DEFAULT 60 CHECK (weather_wind_kmh > 0);

-- ==============================================================================
-- 2. TABLA: weather_regions
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.weather_regions (
  id TEXT PRIMARY KEY CHECK (id ~ '^[a-z0-9_]+$'),
  name TEXT NOT NULL,
  department TEXT NOT NULL,
  crops TEXT[] NOT NULL DEFAULT ARRAY['cafe'],
  latitude NUMERIC(8, 5) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude NUMERIC(8, 5) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  aliases TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.weather_regions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Weather regions are readable by authenticated users" ON public.weather_regions;
CREATE POLICY "Weather regions are readable by authenticated users"
  ON public.weather_regions FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Settings staff manage weather regions" ON public.weather_regions;
CREATE POLICY "Settings staff manage weather regions"
  ON public.weather_regions FOR ALL
  TO authenticated
  USING (public.has_permission('settings'))
  WITH CHECK (public.has_permission('settings'));

-- Coordenadas de un municipio representativo de cada zona.
INSERT INTO public.weather_regions (id, name, department, crops, latitude, longitude, aliases) VALUES
  ('huila', 'Huila', 'Huila', ARRAY['cafe'], 1.85370, -76.05070, ARRAY['Pitalito', 'Garzón', 'La Plata', 'Neiva']),
  ('narino', 'Nariño', 'Nariño', ARRAY['cafe'], 1.60460, -77.13030, ARRAY['La Unión', 'Buesaco', 'Pasto']),
  ('cauca', 'Cauca', 'Cauca', ARRAY['cafe'], 2.44480, -76.61470, ARRAY['Popayán', 'Inzá']),
  ('tolima', 'Tolima', 'Tolima', ARRAY['cafe', 'cacao'], 3.19640, -75.64440, ARRAY['Planadas', 'Chaparral', 'Ibagué']),
  ('antioquia', 'Antioquia', 'Antioquia', ARRAY['cafe', 'cacao'], 5.65660, -75.87890, ARRAY['Andes', 'Jardín', 'Medellín']),
  ('caldas', 'Caldas', 'Caldas', ARRAY['cafe'], 4.98250, -75.60360, ARRAY['Manizales', 'Chinchiná']),
  ('quindio', 'Quindío', 'Quindío', ARRAY['cafe'], 4.53390, -75.68110, ARRAY['Armenia', 'Salento', 'Eje Cafetero']),
  ('risaralda', 'Risaralda', 'Risaralda', ARRAY['cafe'], 4.81330, -75.69610, ARRAY['Pereira', 'Belén de Umbría']),
  ('santander', 'Santander', 'Santander', ARRAY['cacao', 'cafe'], 6.88080, -73.41030, ARRAY['San Vicente de Chucurí', 'Bucaramanga']),
  ('sierra_nevada', 'Sierra Nevada', 'Magdalena', ARRAY['cafe'], 11.14260, -74.11960, ARRAY['Sierra Nevada de Santa Marta', 'Santa Marta', 'Magdalena', 'Minca']),
  ('arauca', 'Arauca', 'Arauca', ARRAY['cacao'], 7.02640, -71.42780, ARRAY['Arauquita', 'Saravena']),
  ('tumaco', 'Tumaco', 'Nariño', ARRAY['cacao'], 1.80670, -78.76470, ARRAY['San Andrés de Tumaco']),
  ('cundinamarca', 'Cundinamarca', 'Cundinamarca', ARRAY['cafe'], 4.43920, -74.52220, ARRAY['Viotá'])
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 3. ASOCIAR UNA OFERTA CON SU REGIÓN
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.normalize_place(p_text TEXT)
RETURNS TEXT AS $$
  SELECT btrim(regexp_replace(
    translate(lower(COALESCE(p_text, '')), 'áéíóúüñ', 'aeiouun'), '\s+', ' ', 'g'));
$$ LANGUAGE sql IMMUTABLE SET search_path = public;

-- 'Huila', 'huila', 'Pitalito' -> 'huila'; 'Nariño'/'Narino' -> 'narino'.
-- Coincidencia exacta por id, nombre o alias; si no, el primer nombre/alias
-- contenido en el texto (ej. 'Huila - Pitalito').
CREATE OR REPLACE FUNCTION public.weather_region_for(p_place TEXT)
RETURNS TEXT AS $$
  WITH keys AS (
    SELECT r.id, public.normalize_place(k) AS key
    FROM public.weather_regions r,
         unnest(r.aliases || r.name || replace(r.id, '_', ' ')) AS k
  )
  SELECT id FROM keys
  WHERE key <> ''
    AND (key = public.normalize_place(p_place)
         OR public.normalize_place(p_place) LIKE '%' || key || '%')
  ORDER BY (key = public.normalize_place(p_place)) DESC, length(key) DESC
  LIMIT 1;
$$ LANGUAGE sql STABLE SET search_path = public;

-- ==============================================================================
-- 4. TABLAS: weather_forecasts (caché) y weather_alerts
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.weather_forecasts (
  region_id TEXT PRIMARY KEY REFERENCES public.weather_regions(id) ON DELETE CASCADE,
  forecast JSONB NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.weather_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_id TEXT NOT NULL REFERENCES public.weather_regions(id) ON DELETE CASCADE,
  alert_date DATE NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('lluvia_fuerte', 'helada', 'calor_extremo', 'viento_fuerte')),
  value NUMERIC NOT NULL,
  threshold NUMERIC NOT NULL,
  message TEXT NOT NULL,
  notified_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (region_id, alert_date, kind)
);

CREATE INDEX IF NOT EXISTS idx_weather_alerts_date ON public.weather_alerts (alert_date DESC);

ALTER TABLE public.weather_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weather_alerts ENABLE ROW LEVEL SECURITY;

-- El clima es información pública para cualquier usuario con sesión.
DROP POLICY IF EXISTS "Forecasts are readable by authenticated users" ON public.weather_forecasts;
CREATE POLICY "Forecasts are readable by authenticated users"
  ON public.weather_forecasts FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Weather alerts are readable by authenticated users" ON public.weather_alerts;
CREATE POLICY "Weather alerts are readable by authenticated users"
  ON public.weather_alerts FOR SELECT
  TO authenticated
  USING (true);

-- Solo la Edge Function (service_role) escribe pronósticos y alertas.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.weather_forecasts, public.weather_alerts
  FROM authenticated, anon;

-- ==============================================================================
-- 5. FUNCIONES DE ALERTA (solo service_role)
-- ==============================================================================
-- Crea la alerta (si no existía ya para esa región, día y tipo) y avisa a los
-- interesados. Devuelve cuántos usuarios recibieron la notificación, o -1 si
-- la alerta ya existía.
CREATE OR REPLACE FUNCTION public.raise_weather_alert(
  p_region_id TEXT,
  p_date DATE,
  p_kind TEXT,
  p_value NUMERIC,
  p_threshold NUMERIC,
  p_message TEXT
)
RETURNS INT AS $$
DECLARE
  v_alert_id UUID;
  v_user UUID;
  v_notified INT := 0;
  v_title TEXT := CASE p_kind
    WHEN 'lluvia_fuerte' THEN 'Alerta de lluvia fuerte'
    WHEN 'helada' THEN 'Alerta de helada'
    WHEN 'calor_extremo' THEN 'Alerta de calor extremo'
    WHEN 'viento_fuerte' THEN 'Alerta de viento fuerte'
  END;
BEGIN
  INSERT INTO public.weather_alerts (region_id, alert_date, kind, value, threshold, message)
  VALUES (p_region_id, p_date, p_kind, p_value, p_threshold, p_message)
  ON CONFLICT (region_id, alert_date, kind) DO NOTHING
  RETURNING id INTO v_alert_id;

  IF v_alert_id IS NULL THEN
    RETURN -1;
  END IF;

  FOR v_user IN
    SELECT o.seller_id
    FROM public.offers o
    WHERE o.status IN ('activa', 'negociando')
      AND public.weather_region_for(o.origin_region) = p_region_id
    UNION
    SELECT u.party
    FROM public.negotiations n
    JOIN public.offers o ON o.id = n.offer_id
    CROSS JOIN LATERAL (VALUES (n.buyer_id), (n.seller_id)) AS u(party)
    WHERE public.weather_region_for(o.origin_region) = p_region_id
      AND (n.status IN ('pending', 'countered', 'accepted')
           OR (n.status = 'confirmed' AND n.shipping_status IS DISTINCT FROM 'entregado'))
  LOOP
    IF public.notify_user(v_user, 'clima', v_title, p_message,
         jsonb_build_object('alert_id', v_alert_id, 'region_id', p_region_id,
                            'alert_date', p_date, 'kind', p_kind)) THEN
      v_notified := v_notified + 1;
    END IF;
  END LOOP;

  UPDATE public.weather_alerts SET notified_count = v_notified WHERE id = v_alert_id;
  RETURN v_notified;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Recibe la respuesta de Open-Meteo (campo daily con time, precipitation_sum,
-- temperature_2m_min, temperature_2m_max, wind_speed_10m_max), la guarda en
-- caché y revisa los primeros p_alert_days días contra los umbrales.
CREATE OR REPLACE FUNCTION public.ingest_weather_forecast(
  p_region_id TEXT,
  p_forecast JSONB,
  p_alert_days INT DEFAULT 3
)
RETURNS JSON AS $$
DECLARE
  v_region public.weather_regions%ROWTYPE;
  v_cfg public.platform_config%ROWTYPE;
  v_daily JSONB := p_forecast -> 'daily';
  v_days INT;
  v_date DATE;
  v_day TEXT;
  v_rain NUMERIC;
  v_tmin NUMERIC;
  v_tmax NUMERIC;
  v_wind NUMERIC;
  v_result INT;
  v_alerts INT := 0;
  v_notified INT := 0;
BEGIN
  SELECT * INTO v_region FROM public.weather_regions WHERE id = p_region_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Región de clima desconocida: %.', p_region_id;
  END IF;
  IF v_daily IS NULL OR jsonb_typeof(v_daily -> 'time') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'El pronóstico no trae datos diarios.';
  END IF;
  SELECT * INTO v_cfg FROM public.platform_config WHERE id;

  INSERT INTO public.weather_forecasts (region_id, forecast, fetched_at)
  VALUES (p_region_id, p_forecast, timezone('utc'::text, now()))
  ON CONFLICT (region_id) DO UPDATE
    SET forecast = EXCLUDED.forecast, fetched_at = EXCLUDED.fetched_at;

  v_days := LEAST(jsonb_array_length(v_daily -> 'time'), GREATEST(COALESCE(p_alert_days, 3), 1));

  FOR i IN 0 .. v_days - 1 LOOP
    v_date := (v_daily -> 'time' ->> i)::DATE;
    v_day := to_char(v_date, 'DD/MM');
    v_rain := round((v_daily -> 'precipitation_sum' ->> i)::NUMERIC, 1);
    v_tmin := round((v_daily -> 'temperature_2m_min' ->> i)::NUMERIC, 1);
    v_tmax := round((v_daily -> 'temperature_2m_max' ->> i)::NUMERIC, 1);
    v_wind := round((v_daily -> 'wind_speed_10m_max' ->> i)::NUMERIC, 1);

    v_result := NULL;
    IF v_rain >= v_cfg.weather_rain_mm THEN
      v_result := public.raise_weather_alert(p_region_id, v_date, 'lluvia_fuerte', v_rain, v_cfg.weather_rain_mm,
        format('Lluvia fuerte en %s el %s: %s mm previstos. Protege el producto en secado y revisa las vías de despacho.',
               v_region.name, v_day, trim_scale(v_rain)));
      IF v_result >= 0 THEN v_alerts := v_alerts + 1; v_notified := v_notified + v_result; END IF;
    END IF;
    IF v_tmin <= v_cfg.weather_frost_c THEN
      v_result := public.raise_weather_alert(p_region_id, v_date, 'helada', v_tmin, v_cfg.weather_frost_c,
        format('Riesgo de helada en %s el %s: mínima de %s °C.', v_region.name, v_day, trim_scale(v_tmin)));
      IF v_result >= 0 THEN v_alerts := v_alerts + 1; v_notified := v_notified + v_result; END IF;
    END IF;
    IF v_tmax >= v_cfg.weather_heat_c THEN
      v_result := public.raise_weather_alert(p_region_id, v_date, 'calor_extremo', v_tmax, v_cfg.weather_heat_c,
        format('Calor extremo en %s el %s: máxima de %s °C.', v_region.name, v_day, trim_scale(v_tmax)));
      IF v_result >= 0 THEN v_alerts := v_alerts + 1; v_notified := v_notified + v_result; END IF;
    END IF;
    IF v_wind >= v_cfg.weather_wind_kmh THEN
      v_result := public.raise_weather_alert(p_region_id, v_date, 'viento_fuerte', v_wind, v_cfg.weather_wind_kmh,
        format('Viento fuerte en %s el %s: hasta %s km/h.', v_region.name, v_day, trim_scale(v_wind)));
      IF v_result >= 0 THEN v_alerts := v_alerts + 1; v_notified := v_notified + v_result; END IF;
    END IF;
  END LOOP;

  RETURN json_build_object('region_id', p_region_id, 'alerts_created', v_alerts, 'notified', v_notified);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Regiones con ofertas activas o tratos en curso: las que revisa check_alerts.
CREATE OR REPLACE FUNCTION public.weather_regions_with_activity()
RETURNS SETOF public.weather_regions AS $$
  SELECT r.* FROM public.weather_regions r
  WHERE EXISTS (
    SELECT 1 FROM public.offers o
    LEFT JOIN public.negotiations n ON n.offer_id = o.id
    WHERE public.weather_region_for(o.origin_region) = r.id
      AND (o.status IN ('activa', 'negociando')
           OR n.status IN ('pending', 'countered', 'accepted')
           OR (n.status = 'confirmed' AND n.shipping_status IS DISTINCT FROM 'entregado'))
  )
  ORDER BY r.id;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION
  public.raise_weather_alert(TEXT, DATE, TEXT, NUMERIC, NUMERIC, TEXT),
  public.ingest_weather_forecast(TEXT, JSONB, INT),
  public.weather_regions_with_activity()
FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION
  public.ingest_weather_forecast(TEXT, JSONB, INT),
  public.weather_regions_with_activity()
TO service_role;
