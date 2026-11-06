-- ==============================================================================
-- REQ-06 a REQ-10: publicar, editar y cerrar ofertas.
-- ==============================================================================
-- E = exportador, E2 = otro exportador, I / J = importadores
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador","name":"Café Primavera"}'),
 ('55555555-5555-5555-5555-555555555555','e2@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','j@x.com','{"role":"importador"}');

CREATE FUNCTION pg_temp.check(label text, cond text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE ok boolean;
BEGIN EXECUTE 'SELECT ' || cond INTO ok; RETURN CASE WHEN ok THEN 'OK    ' ELSE 'FALLO ' END || label; END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SET ROLE authenticated;
\echo '== Publicar (REQ-06 a REQ-10)'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E publica una oferta intentando ponerla confirmada', $$INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country, certifications, status) VALUES ('f0000000-0000-0000-0000-000000000001', auth.uid(), 'cafe', '  Geisha ', 'Huila', 8400, 20, 'Alemania', ARRAY['UTZ'], 'confirmada')$$, true);
SELECT pg_temp.check('Nace activa y con los textos limpios', $$(SELECT status='activa' AND variety='Geisha' FROM offers WHERE id='f0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.t('Publicar a nombre de otro exportador', $$INSERT INTO offers (seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES ('55555555-5555-5555-5555-555555555555', 'cafe', 'Castillo', 'Cauca', 7000, 10, 'España')$$, false);
SELECT pg_temp.t('Precio cero', $$INSERT INTO offers (seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES (auth.uid(), 'cafe', 'Castillo', 'Cauca', 0, 10, 'España')$$, false);
SELECT pg_temp.t('Cantidad cero', $$INSERT INTO offers (seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES (auth.uid(), 'cafe', 'Castillo', 'Cauca', 7000, 0, 'España')$$, false);
SELECT pg_temp.t('Sin pais de destino', $$INSERT INTO offers (seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES (auth.uid(), 'cafe', 'Castillo', 'Cauca', 7000, 10, ' ')$$, false);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Un importador publica', $$INSERT INTO offers (seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES (auth.uid(), 'cafe', 'Castillo', 'Cauca', 7000, 10, 'España')$$, false);

\echo '== Editar'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E ajusta precio, cantidad y destino', $$UPDATE offers SET ask_price_per_mt = 8200, volume_mt = 25, destination_country = 'Bélgica' WHERE id='f0000000-0000-0000-0000-000000000001'$$, true);
SELECT pg_temp.t('E se pone en estado negociando a mano', $$UPDATE offers SET status = 'negociando' WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
SELECT pg_temp.t('E cambia el vendedor', $$UPDATE offers SET seller_id = '55555555-5555-5555-5555-555555555555' WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
SELECT pg_temp.t('E deja la cantidad en cero', $$UPDATE offers SET volume_mt = 0 WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
SELECT pg_temp.as_user('55555555-5555-5555-5555-555555555555') \gset x
SELECT pg_temp.t('Otro exportador edita la oferta de E', $$UPDATE offers SET ask_price_per_mt = 1 WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);

\echo '== Volumen comprometido y cierre'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001', auth.uid(), 8000, 15);
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000001', auth.uid(), 7900, 5);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT accept_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT pg_temp.t('E baja la cantidad por debajo de lo aceptado (15 MT)', $$UPDATE offers SET volume_mt = 10 WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
SELECT pg_temp.t('E cierra con un acuerdo aceptado sin confirmar', $$UPDATE offers SET status = 'cerrada' WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000001', 'Cambio de planes') \gset x
SELECT pg_temp.t('E cierra la oferta', $$UPDATE offers SET status = 'cerrada' WHERE id='f0000000-0000-0000-0000-000000000001'$$, true);
SELECT pg_temp.check('La solicitud en curso de J se cancelo con motivo', $$(SELECT status='cancelled' AND close_reason='El exportador cerró la oferta.' FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000002')$$);
SELECT pg_temp.t('E edita una oferta cerrada', $$UPDATE offers SET ask_price_per_mt = 9000 WHERE id='f0000000-0000-0000-0000-000000000001'$$, false);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Nadie puede solicitar sobre la oferta cerrada', $$INSERT INTO negotiations (offer_id, buyer_id, proposed_price_per_mt) VALUES ('f0000000-0000-0000-0000-000000000001', auth.uid(), 8000)$$, false);

\echo '== El sistema sigue manejando el estado'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES ('f0000000-0000-0000-0000-000000000002', auth.uid(), 'cacao', 'Criollo', 'Sierra', 6000, 5, 'Holanda');
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt) VALUES ('a0000000-0000-0000-0000-000000000003','f0000000-0000-0000-0000-000000000002', auth.uid(), 6000, 5);
SELECT pg_temp.check('La oferta paso sola a negociando', $$(SELECT status='negociando' FROM offers WHERE id='f0000000-0000-0000-0000-000000000002')$$);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT accept_negotiation('a0000000-0000-0000-0000-000000000003') \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000003') \gset x
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Confirmar el trato (el sistema marca la oferta confirmada)', $$SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000003')$$, true);
SELECT pg_temp.check('Oferta confirmada con 0 MT', $$(SELECT status='confirmada' AND volume_mt=0 FROM offers WHERE id='f0000000-0000-0000-0000-000000000002')$$);
RESET ROLE;
