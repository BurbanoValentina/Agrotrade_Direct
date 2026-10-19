-- ==============================================================================
-- REQ-23 (cierre): precios anómalos, calificaciones, reportes, alertas,
-- configuración y estadísticas del panel.
-- ==============================================================================
INSERT INTO auth.users VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','sa@x.com','{}'),
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','o@x.com','{"role":"importador"}');
INSERT INTO staff_members (user_id, is_super_admin) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

SET ROLE authenticated;
\echo '== Precios anomalos (ref cafe 4210, cacao 6870, umbral 40%)'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E publica cafe 8400 (anomalo)', $$INSERT INTO offers (id,seller_id,crop_type,variety,origin_region,ask_price_per_mt,volume_mt,destination_country) VALUES ('ffffffff-0000-0000-0000-000000000001',auth.uid(),'cafe','Geisha','Huila',8400,22,'Alemania')$$, true);
SELECT pg_temp.t('E publica cacao 6200 (normal)', $$INSERT INTO offers (id,seller_id,crop_type,variety,origin_region,ask_price_per_mt,volume_mt,destination_country) VALUES ('ffffffff-0000-0000-0000-000000000002',auth.uid(),'cacao','Criollo','Sierra',6200,15,'Holanda')$$, true);
SELECT pg_temp.t('E cambia volumen (no alerta)', $$UPDATE offers SET volume_mt=20 WHERE id='ffffffff-0000-0000-0000-000000000001'$$, true);
SELECT pg_temp.t('E baja cacao a 1500 (anomalo)', $$UPDATE offers SET ask_price_per_mt=1500 WHERE id='ffffffff-0000-0000-0000-000000000002'$$, true);
RESET ROLE;
SELECT pg_temp.t('Se crearon exactamente 2 alertas (critica y alta)', $$SELECT 1 FROM suspicious_activities HAVING count(*)=2 AND bool_or(severity='critica') AND bool_or(severity='alta')$$, true);
SET ROLE authenticated;

\echo '== Calificaciones'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I envia solicitud', $$INSERT INTO negotiations (id,offer_id,buyer_id,proposed_price_per_mt,requested_volume_mt) VALUES ('bbbbbbbb-0000-0000-0000-000000000001','ffffffff-0000-0000-0000-000000000001',auth.uid(),8000,10)$$, true);
SELECT pg_temp.t('I califica antes del trato', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score) VALUES ('bbbbbbbb-0000-0000-0000-000000000001',auth.uid(),'11111111-1111-1111-1111-111111111111',5)$$, false);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E acepta', $$SELECT accept_negotiation('bbbbbbbb-0000-0000-0000-000000000001')$$, true);
SELECT pg_temp.t('E confirma', $$SELECT confirm_negotiation('bbbbbbbb-0000-0000-0000-000000000001')$$, true);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I confirma', $$SELECT confirm_negotiation('bbbbbbbb-0000-0000-0000-000000000001')$$, true);
SELECT pg_temp.t('I califica a E con 4', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score,comment) VALUES ('bbbbbbbb-0000-0000-0000-000000000001',auth.uid(),'11111111-1111-1111-1111-111111111111',4,'Buen cafe')$$, true);
SELECT pg_temp.t('I califica de nuevo', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score) VALUES ('bbbbbbbb-0000-0000-0000-000000000001',auth.uid(),'11111111-1111-1111-1111-111111111111',1)$$, false);
SELECT pg_temp.t('I se califica a si mismo', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score) VALUES ('bbbbbbbb-0000-0000-0000-000000000001',auth.uid(),auth.uid(),5)$$, false);
SELECT pg_temp.t('I edita su calificacion', $$UPDATE ratings SET score=5$$, false);
SELECT pg_temp.as_user('33333333-3333-3333-3333-333333333333') \gset x
SELECT pg_temp.t('O (ajeno) califica a E', $$INSERT INTO ratings (negotiation_id,rater_id,rated_id,score) VALUES ('bbbbbbbb-0000-0000-0000-000000000001',auth.uid(),'11111111-1111-1111-1111-111111111111',1)$$, false);
SELECT pg_temp.t('El rating de E es el promedio real (4.00)', $$SELECT 1 FROM profiles WHERE id='11111111-1111-1111-1111-111111111111' AND rating=4.00$$, true);

\echo '== Reportes'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I reporta a E', $$INSERT INTO user_reports (reporter_id,reported_user_id,category,description) VALUES (auth.uid(),'11111111-1111-1111-1111-111111111111','incumplimiento','No envio la carga acordada')$$, true);
SELECT pg_temp.t('I crea un reporte ya resuelto', $$INSERT INTO user_reports (reporter_id,reported_user_id,category,description,status) VALUES (auth.uid(),'11111111-1111-1111-1111-111111111111','otro','texto de prueba largo','descartada')$$, false);
SELECT pg_temp.t('I ve su reporte', $$SELECT 1 FROM user_reports$$, true);
SELECT pg_temp.t('I resuelve su propio reporte', $$UPDATE user_reports SET status='accionTomada'$$, false);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E (reportado) ve el reporte', $$SELECT 1 FROM user_reports$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('SA cambia la descripcion', $$UPDATE user_reports SET description='otra cosa distinta'$$, false);
SELECT pg_temp.t('SA resuelve el reporte', $$UPDATE user_reports SET status='accionTomada', resolution='Advertencia enviada'$$, true);
SELECT pg_temp.t('Queda registrado quien reviso', $$SELECT 1 FROM user_reports WHERE reviewed_by=auth.uid()$$, true);

\echo '== Alertas de seguridad'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I ve alertas', $$SELECT 1 FROM suspicious_activities$$, false);
SELECT pg_temp.t('I crea una alerta', $$INSERT INTO suspicious_activities(type,description,severity) VALUES ('intentoFraude','x','alta')$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('SA ve alertas', $$SELECT 1 FROM suspicious_activities$$, true);
SELECT pg_temp.t('SA cambia severidad', $$UPDATE suspicious_activities SET severity='baja'$$, false);
SELECT pg_temp.t('SA marca alerta revisada', $$UPDATE suspicious_activities SET status='revisada' WHERE severity='alta'$$, true);

\echo '== Configuracion y dashboard'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I lee la configuracion', $$SELECT 1 FROM platform_config$$, true);
SELECT pg_temp.t('I cambia la comision', $$UPDATE platform_config SET commission_percent=0$$, false);
SELECT pg_temp.t('I pide stats del dashboard', $$SELECT admin_dashboard_stats()$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('SA cambia precio ref arabica', $$UPDATE platform_config SET arabica_ref_price=7500$$, true);
SELECT pg_temp.t('SA ve el dashboard agregado', $$SELECT admin_dashboard_stats()$$, true);
RESET ROLE;
