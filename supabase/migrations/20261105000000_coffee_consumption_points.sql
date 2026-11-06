-- ==============================================================================
-- AgroTrade Direct — Migración 0012: Puntos de consumo de café
-- REQ-50: mapa con los puntos de mayor consumo de café (capa del Trade Map).
--
-- Columnas = las que lee CoffeeConsumptionPoint.fromJson en la app
-- (lib/models/coffee_consumption_point.dart, rama de Omar).
-- * Lectura: cualquier usuario autenticado.
-- * Escritura: personal con permiso settings (contenido de la plataforma).
--
-- Los datos iniciales son de DEMOSTRACIÓN (is_demo = true) mientras David
-- define el dataset definitivo (decisión D7). Para reemplazarlos: borrar las
-- filas con is_demo = true e insertar las reales con su fuente en `source`.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.coffee_consumption_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city_name TEXT NOT NULL CHECK (length(trim(city_name)) BETWEEN 2 AND 80),
  country TEXT NOT NULL CHECK (length(trim(country)) BETWEEN 2 AND 80),
  latitude NUMERIC(9, 6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude NUMERIC(9, 6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  annual_consumption_tons NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (annual_consumption_tons >= 0),
  main_import_grade TEXT,
  description TEXT CHECK (description IS NULL OR length(description) <= 500),
  -- De dónde sale el dato (estudio, fuente oficial...). Vacío en los datos demo.
  source TEXT,
  is_demo BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (city_name, country)
);

DROP TRIGGER IF EXISTS set_consumption_points_updated_at ON public.coffee_consumption_points;
CREATE TRIGGER set_consumption_points_updated_at
  BEFORE UPDATE ON public.coffee_consumption_points
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.coffee_consumption_points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Consumption points are readable by authenticated users" ON public.coffee_consumption_points;
CREATE POLICY "Consumption points are readable by authenticated users"
  ON public.coffee_consumption_points FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Settings staff can add consumption points" ON public.coffee_consumption_points;
CREATE POLICY "Settings staff can add consumption points"
  ON public.coffee_consumption_points FOR INSERT
  TO authenticated
  WITH CHECK (public.has_permission('settings'));

DROP POLICY IF EXISTS "Settings staff can edit consumption points" ON public.coffee_consumption_points;
CREATE POLICY "Settings staff can edit consumption points"
  ON public.coffee_consumption_points FOR UPDATE
  TO authenticated
  USING (public.has_permission('settings'))
  WITH CHECK (public.has_permission('settings'));

DROP POLICY IF EXISTS "Settings staff can remove consumption points" ON public.coffee_consumption_points;
CREATE POLICY "Settings staff can remove consumption points"
  ON public.coffee_consumption_points FOR DELETE
  TO authenticated
  USING (public.has_permission('settings'));

-- ==============================================================================
-- Datos de demostración (destinos de las ofertas de la app). Las cifras de
-- consumo NO son datos reales: sirven para ver la capa en el mapa.
-- ==============================================================================
INSERT INTO public.coffee_consumption_points
  (city_name, country, latitude, longitude, annual_consumption_tons, main_import_grade, description, is_demo)
VALUES
  ('Hamburgo', 'Alemania', 53.551086, 9.993682, 100000, 'Arábica lavado',
   'Dato de demostración. Puerto de entrada de café a Alemania.', true),
  ('Amberes', 'Bélgica', 51.219448, 4.402464, 60000, 'Arábica lavado',
   'Dato de demostración. Puerto de entrada de café y cacao a Bélgica.', true),
  ('Róterdam', 'Países Bajos', 51.924420, 4.477733, 50000, 'Cacao fino de aroma',
   'Dato de demostración. Puerto de entrada a los Países Bajos.', true),
  ('Barcelona', 'España', 41.385064, 2.173403, 40000, 'Arábica natural',
   'Dato de demostración. Puerto de entrada de café a España.', true),
  ('Le Havre', 'Francia', 49.494370, 0.107929, 40000, 'Arábica lavado',
   'Dato de demostración. Puerto de entrada de café a Francia.', true),
  ('Trieste', 'Italia', 45.649526, 13.776818, 35000, 'Arábica lavado',
   'Dato de demostración. Puerto de entrada de café a Italia.', true)
ON CONFLICT (city_name, country) DO NOTHING;
