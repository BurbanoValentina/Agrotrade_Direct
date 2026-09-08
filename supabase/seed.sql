-- ==============================================================================
-- AgroTrade Direct — Semillas de Prueba (Seed Data)
-- Crea un usuario exportador de ejemplo y 5 ofertas iniciales de Café y Cacao
-- ==============================================================================

DO $$
DECLARE
  v_user_id UUID;
BEGIN
  -- 1. Verificar si ya existe el exportador demo
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'exportador.demo@agrotrade.com';

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();
    
    -- Insertar en auth.users con contraseña encriptada 'password123'
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      'exportador.demo@agrotrade.com',
      crypt('password123', gen_salt('bf')),
      now(),
      '{"name":"Café Primavera Export","role":"exportador","company_name":"Primavera SAS","country":"Colombia"}'::jsonb,
      now(),
      now()
    );
  END IF;

  -- 2. Asegurar el perfil en public.profiles
  INSERT INTO public.profiles (id, role, name, email, company_name, country, rating, completed_trades)
  VALUES (v_user_id, 'exportador', 'Café Primavera Export', 'exportador.demo@agrotrade.com', 'Primavera SAS', 'Colombia', 4.8, 147)
  ON CONFLICT (id) DO UPDATE 
  SET role = 'exportador', name = 'Café Primavera Export', company_name = 'Primavera SAS';

  -- 3. Insertar las 5 ofertas de café y cacao de Colombia a la UE
  INSERT INTO public.offers (
    crop_type, variety, origin_region, origin_country, ask_price_per_mt, volume_mt, destination_country, certifications, status, seller_id
  ) VALUES
    ('cafe', 'Washed Arabica — Geisha', 'Huila', 'Colombia', 8400, 22, 'Alemania', ARRAY['UTZ', 'Rainforest Alliance', 'SCA 87+'], 'activa', v_user_id),
    ('cacao', 'Fine Flavor — Criollo', 'Sierra Nevada', 'Colombia', 6200, 15, 'Países Bajos', ARRAY['Fair Trade'], 'negociando', v_user_id),
    ('cafe', 'Honey Process — Castillo', 'Eje Cafetero', 'Colombia', 7100, 30, 'España', ARRAY['Orgánico UE'], 'activa', v_user_id),
    ('cacao', 'Bulk Grade — Trinitario', 'Nariño', 'Colombia', 5800, 40, 'Bélgica', ARRAY['Rainforest Alliance'], 'confirmada', v_user_id),
    ('cafe', 'Natural Process — Bourbon', 'Sierra Nevada', 'Colombia', 7900, 12, 'Francia', ARRAY['UTZ'], 'activa', v_user_id);

END $$;
