-- ==============================================================================
-- REQ-19: historial de operaciones y línea de tiempo (solo para las partes,
-- REQ-47), y protección del historial al borrar ofertas.
-- ==============================================================================
INSERT INTO auth.users VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','sa@x.com','{"name":"Admin"}'),
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador","name":"Café Primavera","company_name":"Primavera SAS"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador","name":"Hamburg Imports","company_name":"HI GmbH"}'),
 ('33333333-3333-3333-3333-333333333333','x@x.com','{"role":"importador","name":"Otro"}');
INSERT INTO staff_members (user_id, permissions) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '{negotiationManagement}');
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cacao','Criollo','Sierra Nevada',6200,22,'Países Bajos');

SET ROLE authenticated;
-- N1 confirmada tras una contraoferta; N2 rechazada; N3 en curso.
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt, notes)
VALUES ('a0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',auth.uid(),6000,10,'FOB Santa Marta');
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT counter_offer('a0000000-0000-0000-0000-000000000001', 6150, NULL, 'Incluye empaque') \gset x
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT accept_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES ('a0000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000001',auth.uid(),4000,5);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT reject_negotiation('a0000000-0000-0000-0000-000000000002', 'Precio muy bajo') \gset x
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES ('a0000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000001',auth.uid(),6100,2);

\echo '== Historial'
SELECT pg_temp.t('Importador: 2 operaciones cerradas (no la que esta en curso)', $$SELECT 1 FROM my_operation_history() HAVING count(*)=2$$, true);
SELECT pg_temp.t('Importador: total 6150 x 10 = 61500 y contraparte con empresa', $$SELECT 1 FROM my_operation_history(p_status => 'confirmed') WHERE total_usd=61500 AND my_role='comprador' AND counterparty_company='Primavera SAS' AND round_count=2$$, true);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('Exportador: se ve como vendedor', $$SELECT 1 FROM my_operation_history(p_status => 'confirmed') WHERE my_role='vendedor' AND counterparty_name='Hamburg Imports'$$, true);
SELECT pg_temp.t('Filtro de fechas futuras', $$SELECT * FROM my_operation_history(p_from => now() + interval '1 day')$$, false);
SELECT pg_temp.t('Estado no valido', $$SELECT * FROM my_operation_history(p_status => 'pending')$$, false);
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
SELECT pg_temp.t('Tercero ve historial ajeno', $$SELECT * FROM my_operation_history()$$, false);
SELECT pg_temp.t('Tercero ve linea de tiempo ajena', $$SELECT * FROM negotiation_timeline('a0000000-0000-0000-0000-000000000001')$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Admin con negotiationManagement ve historial ajeno (REQ-47)', $$SELECT * FROM my_operation_history()$$, false);
SELECT pg_temp.t('Admin con negotiationManagement ve linea de tiempo (REQ-47)', $$SELECT * FROM negotiation_timeline('a0000000-0000-0000-0000-000000000001')$$, false);

\echo '== Linea de tiempo (importador)'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Orden: 2 propuestas, aceptada, 2 confirmaciones, confirmada', $$SELECT 1 FROM (SELECT string_agg(event_type, ',') AS seq FROM negotiation_timeline('a0000000-0000-0000-0000-000000000001')) s WHERE seq='propuesta,propuesta,aceptada,confirmacion,confirmacion,confirmada'$$, true);
SELECT pg_temp.t('La contraoferta incluye su mensaje', $$SELECT 1 FROM negotiation_timeline('a0000000-0000-0000-0000-000000000001') WHERE description LIKE '%Incluye empaque%'$$, true);
SELECT pg_temp.t('El rechazo incluye su motivo', $$SELECT 1 FROM negotiation_timeline('a0000000-0000-0000-0000-000000000002') WHERE event_type='rechazada' AND description LIKE '%Precio muy bajo%'$$, true);
RESET ROLE;

\echo '== Proteccion del historial'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('Borrar oferta con trato confirmado', $$DELETE FROM offers WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES
 ('f0000000-0000-0000-0000-000000000009','11111111-1111-1111-1111-111111111111','cafe','Sin tratos','Huila',7000,5,'España');
SELECT pg_temp.t('La oferta nueva genero una alerta de precio', $$SELECT 1 FROM suspicious_activities WHERE related_offer_id='f0000000-0000-0000-0000-000000000009'$$, true);
SELECT pg_temp.t('Borrar oferta sin tratos (con alerta de precio)', $$DELETE FROM offers WHERE id='f0000000-0000-0000-0000-000000000009'$$, true);
SELECT pg_temp.t('La alerta se conserva sin referencia', $$SELECT 1 FROM suspicious_activities WHERE related_offer_id IS NULL$$, true);
SELECT pg_temp.as_user(NULL) \gset x
INSERT INTO staff_members (user_id, is_super_admin) SELECT id, true FROM profiles WHERE email='x@x.com';
SET ROLE authenticated;
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
SELECT pg_temp.t('Admin cambia la severidad', $$UPDATE suspicious_activities SET severity='baja'$$, false);
SELECT pg_temp.t('Admin reasigna la alerta a otro usuario', $$UPDATE suspicious_activities SET related_user_id='22222222-2222-2222-2222-222222222222'$$, false);
SELECT pg_temp.t('Admin marca la alerta revisada', $$UPDATE suspicious_activities SET status='revisada'$$, true);
SELECT pg_temp.t('Queda registrado quien reviso', $$SELECT 1 FROM suspicious_activities WHERE reviewed_by=auth.uid()$$, true);
RESET ROLE;
