-- ==============================================================================
-- REQ-47 / REQ-25: Privacidad comercial — pruebas negativas.
-- Solo las dos partes ven precio y términos de su negociación. Nadie más: ni el
-- super admin, ni un admin con todos los permisos, ni otros usuarios, ni un
-- anónimo, por ningún camino (tablas, RPC, auditoría, rondas).
-- ==============================================================================
-- Partes: E (exportador) e I (importador). Ajenos: SA (super admin),
-- A (admin con TODOS los permisos), X (otro importador), E2 (otro exportador).
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador","name":"Exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador","name":"Importador"}'),
 ('33333333-3333-3333-3333-333333333333','x@x.com','{"role":"importador","name":"Otro importador"}'),
 ('55555555-5555-5555-5555-555555555555','e2@x.com','{"role":"exportador","name":"Otro exportador"}'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','sa@x.com','{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','a@x.com','{}');
INSERT INTO staff_members (user_id, is_super_admin, permissions) VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, '{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false, '{dashboard,userManagement,employeeManagement,offerManagement,negotiationManagement,reports,settings,security}');
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cacao','Criollo','Sierra',6200,22,'Holanda');

-- Batería: todos los caminos por los que se podría ver precio o términos de N1.
CREATE FUNCTION pg_temp.battery(who text, u uuid, is_party boolean) RETURNS SETOF text LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_temp.as_user(u);
  RETURN NEXT pg_temp.t(who || ': tabla negotiations', $q$SELECT proposed_price_per_mt FROM negotiations WHERE id='a0000000-0000-0000-0000-000000000001'$q$, is_party);
  RETURN NEXT pg_temp.t(who || ': propuestas y mensajes (rounds)', $q$SELECT price_per_mt, message FROM negotiation_rounds$q$, is_party);
  RETURN NEXT pg_temp.t(who || ': montos en audit_log', $q$SELECT new_value FROM audit_log WHERE table_name='negotiations' AND field IN ('proposed_price_per_mt','requested_volume_mt')$q$, is_party);
  RETURN NEXT pg_temp.t(who || ': historial my_operation_history', $q$SELECT price_per_mt FROM my_operation_history()$q$, is_party);
  RETURN NEXT pg_temp.t(who || ': historial de todos (p_all_users)', $q$SELECT * FROM my_operation_history(NULL, NULL, NULL, true)$q$, false);
  RETURN NEXT pg_temp.t(who || ': linea de tiempo', $q$SELECT * FROM negotiation_timeline('a0000000-0000-0000-0000-000000000001')$q$, is_party);
  IF NOT is_party THEN
    RETURN NEXT pg_temp.t(who || ': actuar sobre la negociacion', $q$SELECT cancel_negotiation('a0000000-0000-0000-0000-000000000001')$q$, false);
  END IF;
END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated, anon;

SET ROLE authenticated;
-- N1: solicitud con notas, contraoferta con mensaje, aceptación y confirmación doble.
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
INSERT INTO negotiations (id, offer_id, buyer_id, proposed_price_per_mt, requested_volume_mt, notes)
VALUES ('a0000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000001',auth.uid(),6000,10,'Necesito entrega en Rotterdam');
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT counter_offer('a0000000-0000-0000-0000-000000000001', 6150, NULL, 'Precio especial por volumen') \gset x
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT accept_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT confirm_negotiation('a0000000-0000-0000-0000-000000000001') \gset x
SELECT pg_temp.t('Preparacion: la negociacion quedo confirmada', $q$SELECT 1 FROM negotiations WHERE status='confirmed'$q$, true);

\echo '== PARTES (ven todo lo suyo)'
SELECT pg_temp.battery('Importador (parte)', '22222222-2222-2222-2222-222222222222', true);
SELECT pg_temp.battery('Exportador (parte)', '11111111-1111-1111-1111-111111111111', true);
\echo '== AJENOS (no ven precio ni terminos)'
SELECT pg_temp.battery('Super admin', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
SELECT pg_temp.battery('Admin con todos los permisos', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false);
SELECT pg_temp.battery('Otro importador', '33333333-3333-3333-3333-333333333333', false);
SELECT pg_temp.battery('Otro exportador', '55555555-5555-5555-5555-555555555555', false);

\echo '== Lo que el personal SI ve: agregados y actividad sin montos'
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Super admin: estadisticas agregadas', $q$SELECT admin_dashboard_stats()$q$, true);
SELECT pg_temp.t('Super admin: cambios de estado en auditoria', $q$SELECT 1 FROM audit_log WHERE table_name='negotiations' AND field='status'$q$, true);
SELECT pg_temp.t('Super admin: precio publicado de la oferta (es publico)', $q$SELECT ask_price_per_mt FROM offers$q$, true);
SELECT '   auditoria de N1 vista por el super admin: ' || string_agg(field || ':' || new_value, ', ' ORDER BY id) FROM audit_log WHERE table_name='negotiations';
RESET ROLE;

\echo '== ANONIMO (sin sesion)'
SET ROLE anon;
SELECT pg_temp.as_user(NULL) \gset x
SELECT pg_temp.t('Anonimo: tabla negotiations', $q$SELECT 1 FROM negotiations$q$, false);
SELECT pg_temp.t('Anonimo: rounds', $q$SELECT 1 FROM negotiation_rounds$q$, false);
SELECT pg_temp.t('Anonimo: audit_log', $q$SELECT 1 FROM audit_log$q$, false);
SELECT pg_temp.t('Anonimo: historial', $q$SELECT * FROM my_operation_history()$q$, false);
SELECT pg_temp.t('Anonimo: linea de tiempo', $q$SELECT * FROM negotiation_timeline('a0000000-0000-0000-0000-000000000001')$q$, false);
RESET ROLE;
