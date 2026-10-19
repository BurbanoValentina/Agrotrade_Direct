-- ==============================================================================
-- REQ-47 / REQ-37: estadísticas agregadas del panel y umbral de 3 tratos
-- (con menos de 3, los montos no se entregan para no revelar un trato).
-- ==============================================================================
INSERT INTO auth.users VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','sa@x.com','{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','d@x.com','{}'),
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','j@x.com','{"role":"importador"}'),
 ('44444444-4444-4444-4444-444444444444','k@x.com','{"role":"importador"}');
INSERT INTO staff_members (user_id, is_super_admin, permissions) VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, '{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false, '{dashboard}');
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cafe','Geisha','Huila',8000,100,'Alemania'),
 ('f0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','cacao','Criollo','Sierra',6000,100,'Holanda'),
 ('f0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','cafe','Castillo','Cauca',7000,50,'España');

-- Cierra un trato completo: solicitud del comprador, aceptación y confirmación doble.
CREATE FUNCTION pg_temp.deal(buyer uuid, offer uuid, price numeric, vol numeric) RETURNS void LANGUAGE plpgsql AS $$
DECLARE nid uuid := gen_random_uuid();
BEGIN
  PERFORM pg_temp.as_user(buyer);
  INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES (nid, offer, buyer, price, vol);
  PERFORM pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  PERFORM accept_negotiation(nid);
  PERFORM confirm_negotiation(nid);
  PERFORM pg_temp.as_user(buyer);
  PERFORM confirm_negotiation(nid);
END $$;
-- Lee una clave del JSON de estadísticas como el admin con permiso dashboard.
CREATE FUNCTION pg_temp.stat(path text[]) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  RETURN admin_dashboard_stats()::jsonb #>> path;
END $$;
CREATE FUNCTION pg_temp.check(label text, ok boolean) RETURNS text LANGUAGE sql AS
  $$ SELECT CASE WHEN ok THEN 'OK    ' ELSE 'FALLO ' END || label $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET ROLE authenticated;
\echo '== Permisos'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Importador pide estadisticas', $$SELECT admin_dashboard_stats()$$, false);
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') \gset x
SELECT pg_temp.t('Admin con solo dashboard', $$SELECT admin_dashboard_stats()$$, true);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Super admin', $$SELECT admin_dashboard_stats()$$, true);

\echo '== Con 2 tratos de cafe: conteos si, montos no'
SELECT pg_temp.deal('22222222-2222-2222-2222-222222222222', 'f0000000-0000-0000-0000-000000000001', 8000, 10);
SELECT pg_temp.deal('33333333-3333-3333-3333-333333333333', 'f0000000-0000-0000-0000-000000000001', 7600, 20);
SELECT pg_temp.check('Tratos confirmados por estado: 2', pg_temp.stat('{negotiationsByStatus,confirmed}') = '2');
SELECT pg_temp.check('Cafe: 2 tratos', pg_temp.stat('{confirmedByCrop,0,deals}') = '2');
SELECT pg_temp.check('Cafe: precio promedio OCULTO (null)', pg_temp.stat('{confirmedByCrop,0,avgPricePerMt}') IS NULL);
SELECT pg_temp.check('Total valor OCULTO (null)', pg_temp.stat('{totalValueUsd}') IS NULL);
SELECT pg_temp.check('Rondas promedio OCULTAS (null)', pg_temp.stat('{avgRoundsToClose}') IS NULL);

\echo '== Con 3 tratos de cafe: aparecen los montos'
SELECT pg_temp.deal('44444444-4444-4444-4444-444444444444', 'f0000000-0000-0000-0000-000000000003', 7000, 10);
SELECT pg_temp.check('Cafe: 3 tratos, 40 MT', pg_temp.stat('{confirmedByCrop,0,deals}') = '3' AND pg_temp.stat('{confirmedByCrop,0,volumeMt}')::numeric = 40);
-- (8000*10 + 7600*20 + 7000*10) / 40 = 302000 / 40 = 7550
SELECT pg_temp.check('Cafe: precio promedio ponderado = 7550.00', pg_temp.stat('{confirmedByCrop,0,avgPricePerMt}')::numeric = 7550);
SELECT pg_temp.check('Total valor = 302000.00', pg_temp.stat('{totalValueUsd}')::numeric = 302000);
SELECT pg_temp.check('Rondas promedio visibles (1.0)', pg_temp.stat('{avgRoundsToClose}')::numeric = 1);

\echo '== Cacao con 1 trato: conteo si, montos no'
SELECT pg_temp.deal('22222222-2222-2222-2222-222222222222', 'f0000000-0000-0000-0000-000000000002', 5900, 5);
SELECT pg_temp.check('Cacao: 1 trato', pg_temp.stat('{confirmedByCrop,1,deals}') = '1');
SELECT pg_temp.check('Cacao: precio promedio OCULTO', pg_temp.stat('{confirmedByCrop,1,avgPricePerMt}') IS NULL);
-- Sin supresion complementaria: total (4 tratos) - cafe (3 tratos) = valor del unico trato de cacao.
SELECT pg_temp.check('Total general OCULTO para que no se deduzca el cacao', pg_temp.stat('{totalValueUsd}') IS NULL AND pg_temp.stat('{totalVolumeMt}') IS NULL);
SELECT pg_temp.check('El cafe (3 tratos) sigue visible', pg_temp.stat('{confirmedByCrop,0,valueUsd}')::numeric = 302000);
SELECT pg_temp.deal('33333333-3333-3333-3333-333333333333', 'f0000000-0000-0000-0000-000000000002', 6100, 5);
SELECT pg_temp.deal('44444444-4444-4444-4444-444444444444', 'f0000000-0000-0000-0000-000000000002', 6000, 10);
SELECT pg_temp.check('Con 3 de cacao vuelve el total general (302000 + 29500 + 30500 + 60000)', pg_temp.stat('{totalValueUsd}')::numeric = 422000);

\echo '== Conteos y desempeno'
-- Una solicitud rechazada para la tasa de cierre: 6 confirmadas / 7 cerradas = 0.857
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES ('a0000000-0000-0000-0000-000000000099','f0000000-0000-0000-0000-000000000002', auth.uid(), 3000, 1);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT reject_negotiation('a0000000-0000-0000-0000-000000000099', 'Muy bajo') \gset x
SELECT pg_temp.check('Tasa de cierre 0.857', pg_temp.stat('{closeRate}')::numeric = 0.857);
SELECT pg_temp.check('Usuarios por rol: 1 exportador, 3 importadores', pg_temp.stat('{usersByRole,exportador}') = '1' AND pg_temp.stat('{usersByRole,importador}') = '3');
SELECT pg_temp.check('Ofertas por estado incluye las 5 claves', (SELECT count(*) FROM jsonb_object_keys((pg_temp.stat('{offersByStatus}'))::jsonb)) = 5);
SELECT pg_temp.check('Serie mensual de 6 meses con 6 tratos este mes', jsonb_array_length(pg_temp.stat('{confirmedByMonth}')::jsonb) = 6 AND (pg_temp.stat('{confirmedByMonth,5,deals}'))::int = 6);
SELECT pg_temp.check('Claves anteriores siguen (totalUsers = 4)', pg_temp.stat('{totalUsers}') = '4');
RESET ROLE;
