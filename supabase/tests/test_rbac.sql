-- ==============================================================================
-- REQ-24: roles, permisos por empleado, bloqueo y cuenta tester.
-- ==============================================================================
-- SA=super admin, A=admin solo ofertas, E=exportador, I=importador,
-- H=quien intenta registrarse como 'staff'
INSERT INTO auth.users VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','sa@x.com','{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','a@x.com','{}'),
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('33333333-3333-3333-3333-333333333333','h@x.com','{"role":"staff"}');
-- Primer super admin (SQL Editor, sin usuario)
INSERT INTO staff_members (user_id, is_super_admin) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country)
VALUES ('ffffffff-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cafe','Geisha','Huila',8400,22,'Alemania');

\echo '== Registro'
SELECT pg_temp.t('Registrarse como staff cae en importador', $q$SELECT 1 FROM profiles WHERE email='h@x.com' AND role='importador'$q$, true);
SELECT pg_temp.t('El super admin queda con rol staff', $q$SELECT 1 FROM profiles WHERE email='sa@x.com' AND role='staff'$q$, true);

SET ROLE authenticated;
\echo '== Usuario normal (importador I)'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I se autoasigna como staff', $$INSERT INTO staff_members(user_id,is_super_admin) VALUES ('22222222-2222-2222-2222-222222222222',true)$$, false);
SELECT pg_temp.t('I se marca tester por UPDATE', $$UPDATE profiles SET is_tester=true WHERE id=auth.uid()$$, false);
SELECT pg_temp.t('I se marca tester por RPC', $$SELECT set_tester('22222222-2222-2222-2222-222222222222', true)$$, false);
SELECT pg_temp.t('I ve lista de empleados', $$SELECT 1 FROM staff_members$$, false);
SELECT pg_temp.t('I borra oferta ajena', $$DELETE FROM offers$$, false);
SELECT pg_temp.t('I se sube su calificacion', $$UPDATE profiles SET rating=5 WHERE id=auth.uid()$$, false);
SELECT pg_temp.t('I envia solicitud (sin bloqueo)', $$INSERT INTO negotiations(offer_id,buyer_id,proposed_price_per_mt,requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222',8000,5)$$, true);

\echo '== Super admin SA'
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('SA crea admin A solo con offerManagement', $$INSERT INTO staff_members(user_id,permissions) VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','{offerManagement}')$$, true);
SELECT pg_temp.t('SA se cambia a si mismo', $$UPDATE staff_members SET is_super_admin=false WHERE user_id=auth.uid()$$, false);
SELECT pg_temp.t('SA marca a I como tester', $$SELECT set_tester('22222222-2222-2222-2222-222222222222', true)$$, true);
SELECT pg_temp.t('SA bloquea a I', $$INSERT INTO blocked_users(user_id,reason) VALUES ('22222222-2222-2222-2222-222222222222','Fraude')$$, true);
SELECT pg_temp.t('SA ve la auditoria (sin montos negociados)', $$SELECT 1 FROM audit_log$$, true);
SELECT pg_temp.t('SA NO ve negociaciones ajenas (REQ-47)', $$SELECT 1 FROM negotiations$$, false);

\echo '== Admin A (solo offerManagement)'
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') \gset x
SELECT pg_temp.t('A se da permiso security', $$UPDATE staff_members SET permissions='{offerManagement,security}' WHERE user_id=auth.uid()$$, false);
SELECT pg_temp.t('A crea otro empleado', $$INSERT INTO staff_members(user_id,permissions) VALUES ('11111111-1111-1111-1111-111111111111','{offerManagement}')$$, false);
SELECT pg_temp.t('A ve el audit_log', $$SELECT 1 FROM audit_log$$, false);
SELECT pg_temp.t('A ve lista de bloqueados', $$SELECT 1 FROM blocked_users$$, false);
SELECT pg_temp.t('A publica una oferta (es staff)', $$INSERT INTO offers(seller_id,crop_type,variety,origin_region,ask_price_per_mt,volume_mt,destination_country) VALUES (auth.uid(),'cafe','x','y',1,1,'z')$$, false);
SELECT pg_temp.t('A edita precio de oferta ajena', $$UPDATE offers SET ask_price_per_mt=8000 WHERE id='ffffffff-0000-0000-0000-000000000001'$$, true);
SELECT pg_temp.t('A lee su propia fila de permisos', $$SELECT 1 FROM staff_members WHERE user_id=auth.uid()$$, true);

\echo '== Importador I bloqueado'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('I bloqueado ve su propio bloqueo', $$SELECT 1 FROM blocked_users WHERE user_id=auth.uid()$$, true);
SELECT pg_temp.t('I bloqueado envia otra solicitud', $$INSERT INTO negotiations(offer_id,buyer_id,proposed_price_per_mt,requested_volume_mt) VALUES ('ffffffff-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222',7000,5)$$, false);
SELECT pg_temp.t('I bloqueado cancela su solicitud', $$SELECT cancel_negotiation(id) FROM negotiations$$, false);
SELECT pg_temp.t('I se desbloquea solo', $$DELETE FROM blocked_users WHERE user_id=auth.uid()$$, false);

\echo '== Exportador E'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E ve en su auditoria el cambio de precio del admin', $$SELECT 1 FROM audit_log WHERE field='ask_price_per_mt' AND changed_by='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'$$, true);
RESET ROLE;
