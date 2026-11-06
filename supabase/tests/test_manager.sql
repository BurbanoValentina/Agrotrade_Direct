-- ==============================================================================
-- REQ-46: rol gerente. Cada fila de la matriz super admin vs. gerente del
-- documento de reparto v2: el gerente consulta, pero no ejecuta ninguna acción.
-- ==============================================================================
-- SA = super admin, G = gerente, E = exportador, I = importador
INSERT INTO auth.users VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','sa@x.com','{}'),
 ('99999999-9999-9999-9999-999999999999','gerente@x.com','{"name":"Gerente"}'),
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('77777777-7777-7777-7777-777777777777','nuevo@x.com','{}');
INSERT INTO staff_members (user_id, is_super_admin) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cafe','Geisha','Huila',8400,22,'Alemania');

\echo '== Un gerente no puede tener permisos de accion'
SELECT pg_temp.t('Gerente con permisos de accion', $$INSERT INTO staff_members (user_id, is_manager, permissions) VALUES ('99999999-9999-9999-9999-999999999999', true, '{userManagement}')$$, false);
SELECT pg_temp.t('Gerente super admin', $$INSERT INTO staff_members (user_id, is_manager, is_super_admin) VALUES ('99999999-9999-9999-9999-999999999999', true, true)$$, false);

SET ROLE authenticated;
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Super admin crea al gerente', $$INSERT INTO staff_members (user_id, is_manager) VALUES ('99999999-9999-9999-9999-999999999999', true)$$, true);
-- Datos para revisar: un reporte, una alerta y un certificado pendiente
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO user_reports (id, reporter_id, reported_user_id, category, description)
VALUES ('d0000000-0000-0000-0000-000000000001', auth.uid(), '11111111-1111-1111-1111-111111111111', 'otro', 'Reporte de prueba para el gerente');
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
INSERT INTO storage.objects (bucket_id, name) VALUES ('certifications', '11111111-1111-1111-1111-111111111111/utz.pdf');
INSERT INTO certifications (id, seller_id, name, file_path) VALUES ('c0000000-0000-0000-0000-000000000001', auth.uid(), 'UTZ', '11111111-1111-1111-1111-111111111111/utz.pdf');
UPDATE offers SET ask_price_per_mt = 1000 WHERE id = 'f0000000-0000-0000-0000-000000000001';

\echo '== Gerente: lo que SI puede (matriz: Si)'
SELECT pg_temp.as_user('99999999-9999-9999-9999-999999999999') \gset x
SELECT pg_temp.t('Se reconoce como gerente (rpc is_manager)', $$SELECT 1 WHERE is_manager()$$, true);
SELECT pg_temp.t('Lee su fila de staff con is_manager', $$SELECT 1 FROM staff_members WHERE user_id = auth.uid() AND is_manager$$, true);
SELECT pg_temp.t('Ver dashboard de metricas (agregadas)', $$SELECT admin_dashboard_stats()$$, true);
SELECT pg_temp.t('Ver reportes de usuarios', $$SELECT 1 FROM user_reports$$, true);
SELECT pg_temp.t('Ver alertas de seguridad', $$SELECT 1 FROM suspicious_activities$$, true);
SELECT pg_temp.t('Ver auditoria (sin montos)', $$SELECT 1 FROM audit_log$$, true);

\echo '== Gerente: lo que NO puede (matriz: No)'
SELECT pg_temp.t('Bloquear usuarios', $$INSERT INTO blocked_users (user_id, reason) VALUES ('22222222-2222-2222-2222-222222222222', 'Prueba')$$, false);
SELECT pg_temp.t('Advertir usuarios', $$SELECT warn_user('11111111-1111-1111-1111-111111111111', 'Advertencia de prueba')$$, false);
SELECT pg_temp.t('Resolver reportes', $$UPDATE user_reports SET status = 'descartada'$$, false);
SELECT pg_temp.t('Invitar o agregar empleados', $$INSERT INTO staff_members (user_id, permissions) VALUES ('77777777-7777-7777-7777-777777777777', '{dashboard}')$$, false);
SELECT pg_temp.t('Gestionar permisos de empleados', $$UPDATE staff_members SET permissions = '{dashboard}' WHERE user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$, false);
SELECT pg_temp.t('Darse permisos a si mismo', $$UPDATE staff_members SET is_manager = false, permissions = '{userManagement}' WHERE user_id = auth.uid()$$, false);
SELECT pg_temp.t('Verificar certificaciones', $$SELECT review_certification('c0000000-0000-0000-0000-000000000001', true)$$, false);
SELECT pg_temp.t('Abrir PDF de certificados', $$SELECT 1 FROM storage.objects WHERE bucket_id = 'certifications'$$, false);
SELECT pg_temp.t('Editar configuracion (platform_config)', $$UPDATE platform_config SET commission_percent = 0$$, false);
SELECT pg_temp.t('Marcar alertas como revisadas', $$UPDATE suspicious_activities SET status = 'revisada'$$, false);
SELECT pg_temp.t('Editar o borrar ofertas ajenas', $$DELETE FROM offers$$, false);
SELECT pg_temp.t('Marcar cuentas tester', $$SELECT set_tester('22222222-2222-2222-2222-222222222222', true)$$, false);
SELECT pg_temp.t('Editar puntos de consumo', $$UPDATE coffee_consumption_points SET annual_consumption_tons = 1$$, false);
SELECT pg_temp.t('Ver precio de negociaciones (REQ-47)', $$SELECT 1 FROM negotiations$$, false);

\echo '== El super admin conserva todo'
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Super admin no es gerente', $$SELECT 1 WHERE NOT is_manager()$$, true);
SELECT pg_temp.t('Super admin resuelve reportes', $$UPDATE user_reports SET status = 'revisada'$$, true);
SELECT pg_temp.t('Super admin verifica certificados', $$SELECT review_certification('c0000000-0000-0000-0000-000000000001', true)$$, true);
SELECT pg_temp.t('Super admin quita el rol de gerente y le da permisos', $$UPDATE staff_members SET is_manager = false, permissions = '{dashboard}' WHERE user_id = '99999999-9999-9999-9999-999999999999'$$, true);
SELECT pg_temp.as_user('99999999-9999-9999-9999-999999999999') \gset x
SELECT pg_temp.t('Ya no es gerente', $$SELECT 1 WHERE NOT is_manager()$$, true);
SELECT pg_temp.t('Sin permiso reports ya no ve todos los reportes', $$SELECT 1 FROM user_reports$$, false);
RESET ROLE;
