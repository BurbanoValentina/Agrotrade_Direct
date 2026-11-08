-- ==============================================================================
-- REQ-50: puntos de consumo de café (lectura para autenticados, edición con
-- permiso settings, datos demo cargados).
-- ==============================================================================
INSERT INTO auth.users VALUES
 ('22222222-2222-2222-2222-222222222222','i@x.com','{"role":"importador"}'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','set@x.com','{}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','sec@x.com','{}');
INSERT INTO staff_members (user_id, permissions) VALUES
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','{settings}'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','{security}');

SELECT pg_temp.t('Se cargaron 6 puntos de demostracion', $$SELECT 1 FROM coffee_consumption_points WHERE is_demo HAVING count(*)=6$$, true);

SET ROLE authenticated;
\echo '== Lectura'
SELECT pg_temp.as_user('22222222-2222-2222-2222-222222222222') \gset x
SELECT pg_temp.t('Importador ve los puntos con las columnas de la app', $$SELECT id, city_name, country, latitude, longitude, annual_consumption_tons, main_import_grade, description FROM coffee_consumption_points$$, true);
SELECT pg_temp.t('Importador agrega un punto', $$INSERT INTO coffee_consumption_points (city_name, country, latitude, longitude) VALUES ('Lyon','Francia',45.76,4.83)$$, false);
SELECT pg_temp.t('Importador edita un punto', $$UPDATE coffee_consumption_points SET annual_consumption_tons = 1$$, false);
SELECT pg_temp.t('Importador borra un punto', $$DELETE FROM coffee_consumption_points$$, false);

\echo '== Personal'
SELECT pg_temp.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') \gset x
SELECT pg_temp.t('Admin sin settings agrega un punto', $$INSERT INTO coffee_consumption_points (city_name, country, latitude, longitude) VALUES ('Lyon','Francia',45.76,4.83)$$, false);
SELECT pg_temp.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') \gset x
SELECT pg_temp.t('Admin con settings agrega un punto real con fuente', $$INSERT INTO coffee_consumption_points (city_name, country, latitude, longitude, annual_consumption_tons, source) VALUES ('Lyon','Francia',45.764043,4.835659,1000,'Fuente de prueba')$$, true);
SELECT pg_temp.t('Admin con settings reemplaza los datos demo', $$DELETE FROM coffee_consumption_points WHERE is_demo$$, true);
SELECT pg_temp.t('Latitud fuera de rango', $$INSERT INTO coffee_consumption_points (city_name, country, latitude, longitude) VALUES ('Error','X',95,0)$$, false);
SELECT pg_temp.t('Ciudad repetida', $$INSERT INTO coffee_consumption_points (city_name, country, latitude, longitude) VALUES ('Lyon','Francia',45.76,4.83)$$, false);
SELECT pg_temp.t('Consumo negativo', $$INSERT INTO coffee_consumption_points (city_name, country, latitude, longitude, annual_consumption_tons) VALUES ('Niza','Francia',43.7,7.26,-5)$$, false);
RESET ROLE;

\echo '== Anonimo'
SET ROLE anon;
SELECT pg_temp.as_user(NULL) \gset x
SELECT pg_temp.t('Anonimo ve los puntos', $$SELECT 1 FROM coffee_consumption_points$$, false);
RESET ROLE;
