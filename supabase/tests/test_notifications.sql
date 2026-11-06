-- ==============================================================================
-- REQ-20 / REQ-49: notificaciones de negociación, preferencias y estados de envío.
-- ==============================================================================
-- E = exportador, I / J = importadores
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador","name":"Café Primavera"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador","name":"Hamburg Imports"}'),
 ('33333333-3333-3333-3333-333333333333','j@x.com','{"role":"importador"}');

CREATE FUNCTION pg_temp.check(label text, cond text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE ok boolean;
BEGIN EXECUTE 'SELECT ' || cond INTO ok; RETURN CASE WHEN ok THEN 'OK    ' ELSE 'FALLO ' END || label; END $$;
-- Cuántas notificaciones de un tipo/título tiene un usuario (sin RLS).
CREATE FUNCTION pg_temp.n(u uuid, title_like text) RETURNS bigint LANGUAGE sql SECURITY DEFINER AS
  $$ SELECT count(*) FROM notifications WHERE user_id = u AND title LIKE title_like $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

\set E '''11111111-1111-1111-1111-111111111111'''
\set I '''22222222-2222-2222-2222-222222222222'''
\set J '''33333333-3333-3333-3333-333333333333'''
\set NI '''a0000000-0000-0000-0000-000000000001'''
\set NJ '''a0000000-0000-0000-0000-000000000002'''

SELECT pg_temp.check('notifications está publicada en Realtime',
  $$EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='notifications')$$);

SET ROLE authenticated;
\echo '== Avisos de negociación'
SELECT pg_temp.as_user(:E) \gset x
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country)
VALUES ('f0000000-0000-0000-0000-000000000001', auth.uid(), 'cafe', 'Geisha', 'Huila', 8400, 20, 'Alemania');

SELECT pg_temp.as_user(:I) \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES (:NI, 'f0000000-0000-0000-0000-000000000001', auth.uid(), 8000, 15);
SELECT pg_temp.check('E recibe "Nueva solicitud de compra" con variedad y montos',
  format($$(SELECT body LIKE '%%Geisha: 15 MT a 8000 USD/MT%%' FROM notifications WHERE user_id=%L AND title='Nueva solicitud de compra')$$, :E));

SELECT pg_temp.as_user(:E) \gset x
SELECT counter_offer(:NI, 8300, NULL, 'Mejor precio por lote') \gset x
SELECT pg_temp.check('I recibe la contraoferta y que es su turno',
  format($$(SELECT count(*) = 1 FROM notifications WHERE user_id=%L AND title='Nueva contraoferta' AND body LIKE '%%Es tu turno%%')$$, :I));

SELECT pg_temp.as_user(:I) \gset x
SELECT counter_offer(:NI, 8150) \gset x
SELECT pg_temp.check('E recibe la contraoferta de I', format('pg_temp.n(%L, %L) = 1', :E, 'Nueva contraoferta'));

SELECT pg_temp.as_user(:J) \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt)
VALUES (:NJ, 'f0000000-0000-0000-0000-000000000001', auth.uid(), 8000, 10);

SELECT pg_temp.as_user(:E) \gset x
SELECT accept_negotiation(:NI) \gset x
SELECT pg_temp.check('I recibe "Propuesta aceptada"', format('pg_temp.n(%L, %L) = 1', :I, 'Propuesta aceptada'));
SELECT pg_temp.check('Quien acepta no se avisa a sí mismo', format('pg_temp.n(%L, %L) = 0', :E, 'Propuesta aceptada'));

SELECT pg_temp.as_user(:I) \gset x
SELECT confirm_negotiation(:NI) \gset x
SELECT pg_temp.check('E recibe "El importador confirmó el trato"', format('pg_temp.n(%L, %L) = 1', :E, 'El importador confirmó%'));

SELECT pg_temp.as_user(:E) \gset x
SELECT confirm_negotiation(:NI) \gset x
SELECT pg_temp.check('I recibe "Trato confirmado"', format('pg_temp.n(%L, %L) = 1', :I, 'Trato confirmado'));
SELECT pg_temp.check('Con ambos confirmados no se envía "falta tu confirmación"', format('pg_temp.n(%L, %L) = 0', :I, 'El exportador confirmó%'));
SELECT pg_temp.check('J recibe el rechazo automático con el motivo (volumen insuficiente)',
  format($$(SELECT body LIKE '%%Volumen insuficiente%%' FROM notifications WHERE user_id=%L AND title='Negociación rechazada')$$, :J));
SELECT pg_temp.check('E (quien confirmó) no recibe el rechazo de J', format('pg_temp.n(%L, %L) = 0', :E, 'Negociación rechazada'));

\echo '== Bandeja: cada quien ve y maneja solo lo suyo'
SELECT pg_temp.as_user(:I) \gset x
SELECT pg_temp.t('I ve sus notificaciones', $$SELECT 1 FROM notifications$$, true);
SELECT pg_temp.t('I ve las de E', format($$SELECT 1 FROM notifications WHERE user_id=%L$$, :E), false);
SELECT pg_temp.t('I marca las suyas como leídas', $$UPDATE notifications SET read_at = now() WHERE read_at IS NULL$$, true);
SELECT pg_temp.t('I cambia el texto de una notificación', $$UPDATE notifications SET title = 'Pago recibido'$$, false);
SELECT pg_temp.t('I marca como leída una de E', format($$UPDATE notifications SET read_at = now() WHERE user_id=%L$$, :E), false);
SELECT pg_temp.t('I se crea una notificación falsa', $$INSERT INTO notifications (user_id, type, title, body) VALUES (auth.uid(), 'sistema', 'Premio', 'Ganaste')$$, false);
SELECT pg_temp.t('I llama la función interna notify_user', format($$SELECT notify_user(%L, 'sistema', 'x', 'y')$$, :E), false);
SELECT pg_temp.t('I borra una notificación suya', format($$DELETE FROM notifications WHERE id = (SELECT id FROM notifications WHERE user_id=%L AND title='Propuesta aceptada')$$, :I), true);

\echo '== Preferencias de alertas'
SELECT pg_temp.t('I guarda sus preferencias', $$INSERT INTO alert_preferences (user_id, weather_alerts, shipping_alerts) VALUES (auth.uid(), true, true)$$, true);
SELECT pg_temp.t('I guarda preferencias de E', format($$INSERT INTO alert_preferences (user_id, shipping_alerts) VALUES (%L, false)$$, :E), false);

\echo '== Estado del envío'
SELECT pg_temp.t('I (importador) marca "preparando"', format($$SELECT update_shipping_status(%L, 'preparando')$$, :NI), false);
SELECT pg_temp.t('I confirma la entrega antes del embarque', format($$SELECT update_shipping_status(%L, 'entregado')$$, :NI), false);
SELECT pg_temp.t('I cambia el envío directo en la tabla', format($$UPDATE negotiations SET shipping_status = 'entregado' WHERE id=%L$$, :NI), false);
SELECT pg_temp.as_user(:E) \gset x
SELECT pg_temp.t('E registra envío en un trato rechazado', format($$SELECT update_shipping_status(%L, 'preparando')$$, :NJ), false);
SELECT pg_temp.t('E marca "entregado"', format($$SELECT update_shipping_status(%L, 'entregado')$$, :NI), false);
SELECT pg_temp.t('E estado inventado', format($$SELECT update_shipping_status(%L, 'perdido')$$, :NI), false);
SELECT pg_temp.t('E marca "preparando" con nota', format($$SELECT update_shipping_status(%L, 'preparando', 'Trillado y empacado en sacos de 70 kg')$$, :NI), true);
SELECT pg_temp.check('I recibe la alerta de envío con la nota',
  format($$(SELECT body = 'Geisha (15 MT): En preparación. Trillado y empacado en sacos de 70 kg' FROM notifications WHERE user_id=%L AND type='envio')$$, :I));

SELECT pg_temp.as_user(:I) \gset x
UPDATE alert_preferences SET shipping_alerts = false WHERE user_id = auth.uid();
SELECT pg_temp.as_user(:E) \gset x
SELECT pg_temp.t('E marca "embarcado"', format($$SELECT update_shipping_status(%L, 'embarcado', 'Contenedor MSCU1234567, Buenaventura')$$, :NI), true);
SELECT pg_temp.check('Con las alertas de envío apagadas, I no recibe aviso',
  format($$(SELECT count(*) = 1 FROM notifications WHERE user_id=%L AND type='envio')$$, :I));
SELECT pg_temp.t('E retrocede a "preparando"', format($$SELECT update_shipping_status(%L, 'preparando')$$, :NI), false);
SELECT pg_temp.t('E marca "en_puerto"', format($$SELECT update_shipping_status(%L, 'en_puerto')$$, :NI), true);
SELECT pg_temp.t('E inserta un evento de envío a mano', format($$INSERT INTO shipment_events (negotiation_id, status) VALUES (%L, 'entregado')$$, :NI), false);

SELECT pg_temp.as_user(:I) \gset x
SELECT pg_temp.t('I confirma la entrega', format($$SELECT update_shipping_status(%L, 'entregado')$$, :NI), true);
SELECT pg_temp.check('E recibe la alerta de entrega', format($$(SELECT count(*) = 1 FROM notifications WHERE user_id=%L AND type='envio' AND body LIKE '%%Entregado%%')$$, :E));
SELECT pg_temp.t('I ve el historial del envío', format($$SELECT 1 FROM shipment_events WHERE negotiation_id=%L$$, :NI), true);
SELECT pg_temp.check('La línea de tiempo muestra los 4 pasos del envío',
  format($$(SELECT count(*) = 4 FROM negotiation_timeline(%L) WHERE event_type = 'envio')$$, :NI));

SELECT pg_temp.as_user(:J) \gset x
SELECT pg_temp.t('J (ajeno al trato) ve el envío de I', format($$SELECT 1 FROM shipment_events WHERE negotiation_id=%L$$, :NI), false);
SELECT pg_temp.as_user(:E) \gset x
SELECT pg_temp.t('E cambia el envío después de entregado', format($$SELECT update_shipping_status(%L, 'en_puerto')$$, :NI), false);
RESET ROLE;
