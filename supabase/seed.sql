-- ==============================================================================
-- AgroTrade Direct — Semillas de Prueba (Seed Data)
-- Completa el perfil del exportador demo y crea 5 ofertas de Café y Cacao.
--
-- REQUISITO: crear antes el usuario desde el Dashboard de Supabase
--   Authentication → Users → Add user
--   correo: exportador.demo@agrotrade.com | contraseña: password123
--   marcar "Auto Confirm User"
-- (Insertar directamente en auth.users deja columnas internas en NULL y el
-- login falla con "Database error querying schema".)
--
-- Se puede ejecutar varias veces: no duplica las ofertas.
-- ==============================================================================

DO $$
DECLARE
  v_user_id UUID;
BEGIN
  -- 1. Buscar el exportador demo creado desde el Dashboard
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'exportador.demo@agrotrade.com';

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Primero crea el usuario exportador.demo@agrotrade.com en Authentication → Users → Add user';
  END IF;

  -- 2. Asegurar el perfil en public.profiles
  INSERT INTO public.profiles (id, role, name, email, company_name, country, rating, completed_trades)
  VALUES (v_user_id, 'exportador', 'Café Primavera Export', 'exportador.demo@agrotrade.com', 'Primavera SAS', 'Colombia', 4.8, 147)
  ON CONFLICT (id) DO UPDATE 
  SET role = 'exportador', name = 'Café Primavera Export', company_name = 'Primavera SAS';

  -- 3. Insertar las 5 ofertas de café y cacao de Colombia a la UE (solo si aún no existen)
  IF EXISTS (SELECT 1 FROM public.offers WHERE seller_id = v_user_id) THEN
    RAISE NOTICE 'El exportador demo ya tiene ofertas; no se insertan duplicados.';
    RETURN;
  END IF;

  INSERT INTO public.offers (
    crop_type, variety, origin_region, origin_country, ask_price_per_mt, volume_mt, destination_country, certifications, status, seller_id
  ) VALUES
    ('cafe', 'Washed Arabica — Geisha', 'Huila', 'Colombia', 8400, 22, 'Alemania', ARRAY['UTZ', 'Rainforest Alliance', 'SCA 87+'], 'activa', v_user_id),
    ('cacao', 'Fine Flavor — Criollo', 'Sierra Nevada', 'Colombia', 6200, 15, 'Países Bajos', ARRAY['Fair Trade'], 'negociando', v_user_id),
    ('cafe', 'Honey Process — Castillo', 'Eje Cafetero', 'Colombia', 7100, 30, 'España', ARRAY['Orgánico UE'], 'activa', v_user_id),
    ('cacao', 'Bulk Grade — Trinitario', 'Nariño', 'Colombia', 5800, 40, 'Bélgica', ARRAY['Rainforest Alliance'], 'confirmada', v_user_id),
    ('cafe', 'Natural Process — Bourbon', 'Sierra Nevada', 'Colombia', 7900, 12, 'Francia', ARRAY['UTZ'], 'activa', v_user_id);

END $$;
