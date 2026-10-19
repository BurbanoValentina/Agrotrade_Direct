-- ==============================================================================
-- REQ-33: advertencias a usuarios y suspensión automática a la 3.ª.
-- ==============================================================================
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador","name":"Exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador","name":"Importador"}'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','a@x.com','{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','s@x.com','{}');
INSERT INTO staff_members (user_id, permissions) VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','{userManagement}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','{offerManagement}');

SET ROLE authenticated;
-- El importador reporta al exportador
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO user_reports (id, reporter_id, reported_user_id, category, description)
VALUES ('d0000000-0000-0000-0000-000000000001', auth.uid(), '11111111-1111-1111-1111-111111111111', 'incumplimiento', 'No envió la carga en la fecha acordada');

\echo '== Permisos'
SELECT pg_temp.t('Importador advierte', $$SELECT warn_user('11111111-1111-1111-1111-111111111111', 'Prueba de advertencia')$$, false);
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') \gset x
SELECT pg_temp.t('Admin sin userManagement advierte', $$SELECT warn_user('11111111-1111-1111-1111-111111111111', 'Prueba de advertencia')$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Admin se advierte a si mismo', $$SELECT warn_user(auth.uid(), 'Prueba de advertencia')$$, false);
SELECT pg_temp.t('Admin advierte a otro staff', $$SELECT warn_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Prueba de advertencia')$$, false);
SELECT pg_temp.t('Motivo demasiado corto', $$SELECT warn_user('11111111-1111-1111-1111-111111111111', 'x')$$, false);
SELECT pg_temp.t('Reporte que no es de ese usuario', $$SELECT warn_user('22222222-2222-2222-2222-222222222222', 'Prueba de advertencia', 'd0000000-0000-0000-0000-000000000001')$$, false);
SELECT pg_temp.t('Insertar advertencia directo', $$INSERT INTO user_warnings (user_id, reason) VALUES ('11111111-1111-1111-1111-111111111111', 'directo sin rpc')$$, false);

\echo '== Advertencias y suspension automatica'
SELECT pg_temp.t('1a advertencia (desde el reporte)', $$SELECT 1 WHERE (warn_user('11111111-1111-1111-1111-111111111111', 'Incumplimiento de entrega', 'd0000000-0000-0000-0000-000000000001')->>'auto_blocked')::boolean = false$$, true);
SELECT pg_temp.t('El reporte quedo como accionTomada', $$SELECT 1 FROM user_reports WHERE status='accionTomada' AND reviewed_by=auth.uid()$$, true);
SELECT pg_temp.t('2a advertencia', $$SELECT 1 WHERE (warn_user('11111111-1111-1111-1111-111111111111', 'Lenguaje ofensivo en el chat')->>'warnings_count')::int = 2$$, true);
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('El exportador ve sus 2 advertencias sin leer', $$SELECT 1 FROM user_warnings WHERE acknowledged_at IS NULL HAVING count(*)=2$$, true);
SELECT pg_temp.t('Exportador marca una como leida', $$SELECT acknowledge_warning(id) FROM user_warnings ORDER BY created_at LIMIT 1$$, true);
SELECT pg_temp.t('Exportador edita una advertencia', $$UPDATE user_warnings SET reason = 'no fue nada'$$, false);
SELECT pg_temp.t('Exportador borra sus advertencias', $$DELETE FROM user_warnings$$, false);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Importador ve advertencias ajenas', $$SELECT 1 FROM user_warnings$$, false);
SELECT pg_temp.t('Importador marca como leida una ajena', $$SELECT acknowledge_warning(id) FROM user_warnings$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('3a advertencia suspende la cuenta', $$SELECT 1 WHERE (warn_user('11111111-1111-1111-1111-111111111111', 'Precios falsos en ofertas')->>'auto_blocked')::boolean$$, true);
SELECT pg_temp.t('Bloqueo con motivo automatico', $$SELECT 1 FROM blocked_users WHERE reason LIKE 'Suspensión automática: 3 advertencias%' AND blocked_by=auth.uid()$$, true);
SELECT pg_temp.t('4a advertencia no duplica el bloqueo', $$SELECT 1 WHERE (warn_user('11111111-1111-1111-1111-111111111111', 'Otra falta despues del bloqueo')->>'auto_blocked')::boolean = false AND (SELECT count(*) FROM blocked_users) = 1$$, true);
RESET ROLE;
