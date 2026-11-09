-- ==============================================================================
-- REQ-15 / 16 / 17: negociación estilo InDrive, 10 rondas, confirmación doble,
-- descuento de volumen y rechazo automático de solicitudes que ya no caben.
-- ==============================================================================
-- E = exportador, I = importador, J = otro importador, X = ajeno
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('44444444-4444-4444-4444-444444444444','j@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','x@x.com','{"role":"importador"}');
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cacao','Criollo','Sierra',6200,22,'Holanda'),
 ('f0000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','cacao','Trinitario','Nariño',5800,40,'Bélgica'),
 ('f0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','cacao','Nacional','Tumaco',6000,5,'Francia');

CREATE FUNCTION pg_temp.check(label text, cond text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE ok boolean;
BEGIN EXECUTE 'SELECT ' || cond INTO ok; RETURN CASE WHEN ok THEN 'OK    ' ELSE 'FALLO ' END || label; END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET ROLE authenticated;
\echo '== 1. Ida y vuelta (oferta de 22 MT)'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I solicita 10 MT a 6000', $$INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',auth.uid(),6000,10)$$, true);
SELECT pg_temp.check('La oferta pasa a negociando', $$(SELECT status FROM offers WHERE id='f0000000-0000-0000-0000-000000000001')='negociando'$$);
SELECT pg_temp.t('I contraoferta sin ser su turno', $$SELECT counter_offer('a0000000-0000-0000-0000-000000000001', 6050)$$, false);
SELECT pg_temp.t('I acepta su propia propuesta', $$SELECT accept_negotiation('a0000000-0000-0000-0000-000000000001')$$, false);
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
SELECT pg_temp.t('X (ajeno) acepta', $$SELECT accept_negotiation('a0000000-0000-0000-0000-000000000001')$$, false);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E contraoferta 6150', $$SELECT counter_offer('a0000000-0000-0000-0000-000000000001', 6150, NULL, 'Precio con empaque incluido')$$, true);
SELECT pg_temp.check('Estado countered, ronda 2', $$(SELECT status='countered' AND round_count=2 FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.t('E actualiza negotiations directamente', $$UPDATE negotiations SET status='accepted'$$, false);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I contraoferta 6100', $$SELECT counter_offer('a0000000-0000-0000-0000-000000000001', 6100)$$, true);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E acepta 6100', $$SELECT accept_negotiation('a0000000-0000-0000-0000-000000000001')$$, true);
SELECT pg_temp.t('E contraoferta tras aceptar', $$SELECT counter_offer('a0000000-0000-0000-0000-000000000001', 7000)$$, false);
SELECT pg_temp.t('Calificar antes de confirmar', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score) VALUES ('a0000000-0000-0000-0000-000000000001',auth.uid(),'22222222-2222-2222-2222-222222222222',5)$$, false);

\echo '== 2. Otra solicitud mientras tanto (J pide 15 MT)'
SELECT pg_temp.as_user('44444444-4444-4444-4444-444444444444') \gset x
SELECT pg_temp.t('J solicita 15 MT', $$INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000001',auth.uid(),6100,15)$$, true);

\echo '== 3. Confirmacion doble (REQ-17)'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I confirma', $$SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001')$$, true);
SELECT pg_temp.check('Sigue accepted con una confirmacion', $$(SELECT status='accepted' FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.t('I confirma otra vez', $$SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001')$$, false);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E confirma (cierra el trato)', $$SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001')$$, true);
SELECT pg_temp.check('Trato confirmed', $$(SELECT status='confirmed' FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.check('Oferta: 22 - 10 = 12 MT y vuelve a activa', $$(SELECT volume_mt=12 AND status='activa' FROM offers WHERE id='f0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.check('Solicitud de J (15 > 12) rechazada sola', $$(SELECT status='rejected' AND close_reason LIKE 'Volumen insuficiente%' FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000002')$$);
SELECT pg_temp.check('Tratos completados: 1 cada parte', $$(SELECT count(*)=2 FROM profiles WHERE completed_trades=1)$$);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I califica a E tras confirmar', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score) VALUES ('a0000000-0000-0000-0000-000000000001',auth.uid(),'11111111-1111-1111-1111-111111111111',5)$$, true);
SELECT pg_temp.t('I ve las 3 rondas', $$SELECT 1 FROM negotiation_rounds WHERE negotiation_id='a0000000-0000-0000-0000-000000000001' HAVING count(*)=3$$, true);
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
SELECT pg_temp.t('X (ajeno) ve rondas', $$SELECT 1 FROM negotiation_rounds$$, false);

\echo '== 4. Limite de 10 rondas'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I solicita (ronda 1)', $$INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000002',auth.uid(),5000,10)$$, true);
DO $$ BEGIN
  FOR r IN 2..10 LOOP
    IF r % 2 = 0 THEN PERFORM pg_temp.as_user('11111111-1111-1111-1111-111111111111');
    ELSE PERFORM pg_temp.as_user('22222222-2222-2222-2222-222222222222'); END IF;
    PERFORM counter_offer('a0000000-0000-0000-0000-000000000003', 5000 + r * 50);
  END LOOP;
END $$;
SELECT pg_temp.check('Ronda 10, turno del importador', $$(SELECT round_count=10 AND status='countered' FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000003')$$);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I intenta ronda 11', $$SELECT counter_offer('a0000000-0000-0000-0000-000000000003', 5600)$$, false);
SELECT pg_temp.t('I acepta en la ronda 10', $$SELECT accept_negotiation('a0000000-0000-0000-0000-000000000003')$$, true);

\echo '== 5. Cancelaciones'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E se echa atras antes de confirmar', $$SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000003', 'Cambio de condiciones')$$, true);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I vuelve a solicitar', $$INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000004','f0000000-0000-0000-0000-000000000002',auth.uid(),5500,5)$$, true);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E cancela una solicitud en curso', $$SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000004')$$, false);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I cancela su solicitud en curso', $$SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000004')$$, true);
SELECT pg_temp.t('I cancela una ya cancelada', $$SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000004')$$, false);

\echo '== 6. Oferta agotada (5 MT)'
SELECT pg_temp.t('I solicita los 5 MT', $$INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000005','f0000000-0000-0000-0000-000000000003',auth.uid(),6000,5)$$, true);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E acepta', $$SELECT accept_negotiation('a0000000-0000-0000-0000-000000000005')$$, true);
SELECT pg_temp.t('E confirma', $$SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000005')$$, true);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I confirma (vende todo)', $$SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000005')$$, true);
SELECT pg_temp.check('Oferta en 0 MT y confirmada', $$(SELECT volume_mt=0 AND status='confirmada' FROM offers WHERE id='f0000000-0000-0000-0000-000000000003')$$);
SELECT pg_temp.as_user('44444444-4444-4444-4444-444444444444') \gset x
SELECT pg_temp.t('J solicita a una oferta agotada', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('f0000000-0000-0000-0000-000000000003',auth.uid(),6000,1)$$, false);

\echo '== 7. Usuario bloqueado'
RESET ROLE;
INSERT INTO blocked_users (user_id, reason) VALUES ('22222222-2222-2222-2222-222222222222','Prueba');
SET ROLE authenticated;
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I bloqueado intenta actuar', $$SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000001')$$, false);
RESET ROLE;
SELECT pg_temp.check('Auditoria registra el ida y vuelta de precios', $$(SELECT count(*)=2 FROM audit_log WHERE record_id='a0000000-0000-0000-0000-000000000001' AND action='UPDATE' AND field='proposed_price_per_mt')$$);
