-- ==============================================================================
-- REQ-14: reglas de la solicitud de compra, con mensajes claros.
-- ==============================================================================
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','b@x.com','{"role":"importador"}');
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country, status) VALUES
 ('ffffffff-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cafe','Geisha','Huila',8400,22,'Alemania','activa'),
 ('ffffffff-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','cacao','Trinitario','Nariño',5800,40,'Bélgica','confirmada'),
 ('ffffffff-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','cafe','Castillo','Cauca',7100,22,'España','activa');
INSERT INTO blocked_users (user_id, reason) VALUES ('33333333-3333-3333-3333-333333333333','Prueba');

SET ROLE authenticated;
\echo '== Importador I (casos validos)'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Solicitud con seller_id FALSO y sin volumen', $$INSERT INTO negotiations (offer_id, buyer_id, seller_id, proposed_price_per_mt) VALUES ('ffffffff-0000-0000-0000-000000000001', auth.uid(), '33333333-3333-3333-3333-333333333333', 8000)$$, true);
SELECT pg_temp.t('La base corrige el vendedor y pone el volumen completo', $$SELECT 1 FROM negotiations WHERE seller_id='11111111-1111-1111-1111-111111111111' AND requested_volume_mt=22$$, true);
SELECT pg_temp.t('I cancela su solicitud', $$SELECT cancel_negotiation(id) FROM negotiations$$, true);
SELECT pg_temp.t('Nueva solicitud con volumen parcial y notas', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt, notes) VALUES ('ffffffff-0000-0000-0000-000000000001', auth.uid(), 8100, 10, 'Entrega FOB Buenaventura')$$, true);

\echo '== Rechazos con mensaje claro'
SELECT pg_temp.t('Solicitud duplicada', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000001', auth.uid(), 7900, 5)$$, false);
SELECT pg_temp.t('Volumen mayor al disponible (22 MT)', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000003', auth.uid(), 5000, 99)$$, false);
SELECT pg_temp.t('Volumen cero', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000003', auth.uid(), 5000, 0)$$, false);
SELECT pg_temp.t('Oferta cerrada', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000002', auth.uid(), 5000, 5)$$, false);
SELECT pg_temp.t('Oferta inexistente', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt) VALUES (gen_random_uuid(), auth.uid(), 5000)$$, false);
SELECT pg_temp.t('Notas de 501 caracteres', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt, notes) VALUES ('ffffffff-0000-0000-0000-000000000003', auth.uid(), 5000, 1, repeat('x', 501))$$, false);
SELECT pg_temp.t('Precio cero', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000003', auth.uid(), 0, 1)$$, false);
SELECT pg_temp.t('Suplantar a otro comprador', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt) VALUES ('ffffffff-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 8000)$$, false);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('Exportador envia solicitud', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt) VALUES ('ffffffff-0000-0000-0000-000000000003', auth.uid(), 8000)$$, false);
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
SELECT pg_temp.t('Importador bloqueado', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt) VALUES ('ffffffff-0000-0000-0000-000000000003', auth.uid(), 8000)$$, false);
RESET ROLE;
