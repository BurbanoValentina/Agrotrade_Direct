-- ==============================================================================
-- REQ-36: verificación de certificaciones (bucket, tabla, revisión y sello).
-- ==============================================================================
-- E = exportador, E2 = otro exportador, I = importador,
-- A = admin offerManagement, S = admin sin ese permiso
INSERT INTO auth.users VALUES
 ('11111111-1111-1111-1111-111111111111','e@x.com','{"role":"exportador","name":"Café Primavera"}'),
 ('55555555-5555-5555-5555-555555555555','e2@x.com','{"role":"exportador","name":"Otro Exportador"}'),
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','a@x.com','{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','s@x.com','{}');
INSERT INTO staff_members (user_id, permissions) VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','{offerManagement}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','{security}');
INSERT INTO offers (id, seller_id, crop_type, variety, origin_region, ask_price_per_mt, volume_mt, destination_country, certifications) VALUES
 ('f0000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','cacao','Criollo','Sierra',6200,22,'Holanda', ARRAY['UTZ','Rainforest Alliance','Fair Trade']);

CREATE FUNCTION pg_temp.badges() RETURNS text[] LANGUAGE sql SECURITY DEFINER AS
  $$ SELECT verified_certifications(o) FROM offers o WHERE id='f0000000-0000-0000-0000-000000000001' $$;
CREATE FUNCTION pg_temp.check(label text, cond text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE ok boolean;
BEGIN EXECUTE 'SELECT ' || cond INTO ok; RETURN CASE WHEN ok THEN 'OK    ' ELSE 'FALLO ' END || label; END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated;

SELECT pg_temp.check('Bucket privado, 5 MB, solo PDF', $$(SELECT NOT public AND file_size_limit=5242880 AND allowed_mime_types='{application/pdf}' FROM storage.buckets WHERE id='certifications')$$);
SET ROLE authenticated;

\echo '== Subida de archivos'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E sube PDF a su carpeta', $$INSERT INTO storage.objects (bucket_id, name) VALUES ('certifications', '11111111-1111-1111-1111-111111111111/utz.pdf')$$, true);
SELECT pg_temp.t('E sube segundo PDF', $$INSERT INTO storage.objects (bucket_id, name) VALUES ('certifications', '11111111-1111-1111-1111-111111111111/fair.pdf')$$, true);
SELECT pg_temp.t('E sube a la carpeta de otro', $$INSERT INTO storage.objects (bucket_id, name) VALUES ('certifications', '55555555-5555-5555-5555-555555555555/x.pdf')$$, false);
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Importador sube PDF', $$INSERT INTO storage.objects (bucket_id, name) VALUES ('certifications', '22222222-2222-2222-2222-222222222222/x.pdf')$$, false);

\echo '== Registro del certificado'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E registra UTZ intentando ponerlo verified', $$INSERT INTO certifications (id, seller_id, name, valid_until, file_path, status) VALUES ('c0000000-0000-0000-0000-000000000001', auth.uid(), 'utz ', current_date + 365, '11111111-1111-1111-1111-111111111111/utz.pdf', 'verified')$$, true);
SELECT pg_temp.check('El estado se forzo a pending y el nombre se limpio', $$(SELECT status='pending' AND name='utz' FROM certifications WHERE id='c0000000-0000-0000-0000-000000000001')$$);
SELECT pg_temp.t('E registra Fair Trade', $$INSERT INTO certifications (id, seller_id, name, file_path) VALUES ('c0000000-0000-0000-0000-000000000002', auth.uid(), 'Fair Trade', '11111111-1111-1111-1111-111111111111/fair.pdf')$$, true);
SELECT pg_temp.t('Certificado sin PDF subido', $$INSERT INTO certifications (seller_id, name, file_path) VALUES (auth.uid(), 'SCA', '11111111-1111-1111-1111-111111111111/fantasma.pdf')$$, false);
SELECT pg_temp.t('Certificado vencido', $$INSERT INTO certifications (seller_id, name, valid_until, file_path) VALUES (auth.uid(), 'Viejo', current_date - 1, '11111111-1111-1111-1111-111111111111/utz.pdf')$$, false);
SELECT pg_temp.t('Usar el PDF de otro exportador', $$INSERT INTO certifications (seller_id, name, file_path) VALUES (auth.uid(), 'Robado', '55555555-5555-5555-5555-555555555555/x.pdf')$$, false);
SELECT pg_temp.t('E se autoverifica por UPDATE', $$UPDATE certifications SET status='verified'$$, false);
SELECT pg_temp.t('E se autoverifica por RPC', $$SELECT review_certification('c0000000-0000-0000-0000-000000000001', true)$$, false);
SELECT pg_temp.check('Sin verificacion no hay sello', $$pg_temp.badges() = '{}'$$);

\echo '== Quien ve que'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Importador lista certificados', $$SELECT 1 FROM certifications$$, false);
SELECT pg_temp.t('Importador abre el PDF', $$SELECT 1 FROM storage.objects WHERE bucket_id='certifications'$$, false);
SELECT pg_temp.as_user('55555555-5555-5555-5555-555555555555') \gset x
SELECT pg_temp.t('Otro exportador abre el PDF', $$SELECT 1 FROM storage.objects WHERE bucket_id='certifications'$$, false);
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') \gset x
SELECT pg_temp.t('Admin sin offerManagement revisa', $$SELECT review_certification('c0000000-0000-0000-0000-000000000001', true)$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Admin ve pendientes', $$SELECT 1 FROM certifications WHERE status='pending'$$, true);
SELECT pg_temp.t('Admin abre el PDF', $$SELECT 1 FROM storage.objects WHERE bucket_id='certifications'$$, true);

\echo '== Revision'
SELECT pg_temp.t('Admin aprueba UTZ', $$SELECT review_certification('c0000000-0000-0000-0000-000000000001', true)$$, true);
SELECT pg_temp.t('Admin rechaza Fair Trade sin motivo', $$SELECT review_certification('c0000000-0000-0000-0000-000000000002', false)$$, false);
SELECT pg_temp.t('Admin rechaza Fair Trade con motivo', $$SELECT review_certification('c0000000-0000-0000-0000-000000000002', false, 'Documento ilegible')$$, true);
SELECT pg_temp.t('Admin aprueba uno ya rechazado', $$SELECT review_certification('c0000000-0000-0000-0000-000000000002', true)$$, false);
SELECT pg_temp.check('Sello en la oferta: UTZ (sin distinguir mayusculas)', $$pg_temp.badges() = '{UTZ}'$$);

\echo '== Borrados'
SELECT pg_temp.as_user('11111111-1111-1111-1111-111111111111') \gset x
SELECT pg_temp.t('E borra el PDF verificado', $$DELETE FROM storage.objects WHERE name='11111111-1111-1111-1111-111111111111/utz.pdf'$$, false);
SELECT pg_temp.t('E borra el certificado verificado', $$DELETE FROM certifications WHERE id='c0000000-0000-0000-0000-000000000001'$$, false);
SELECT pg_temp.t('E borra el certificado rechazado', $$DELETE FROM certifications WHERE id='c0000000-0000-0000-0000-000000000002'$$, true);
SELECT pg_temp.t('E borra el PDF del rechazado', $$DELETE FROM storage.objects WHERE name='11111111-1111-1111-1111-111111111111/fair.pdf'$$, true);

\echo '== Revocar y vencimiento'
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Admin revoca UTZ verificado', $$SELECT review_certification('c0000000-0000-0000-0000-000000000001', false, 'Revocado por el emisor')$$, true);
SELECT pg_temp.check('Revocado: sin sello', $$pg_temp.badges() = '{}'$$);
RESET ROLE;
UPDATE certifications SET status='verified', valid_until = current_date - 1 WHERE id='c0000000-0000-0000-0000-000000000001';
SELECT pg_temp.check('Verificado pero vencido ayer: sin sello', $$pg_temp.badges() = '{}'$$);
