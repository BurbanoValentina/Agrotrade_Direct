-- ==============================================================================
-- Ayudantes comunes de las pruebas (se cargan antes de cada archivo de prueba).
--   pg_temp.as_user(uuid)          cambia el usuario actual (NULL = anónimo)
--   pg_temp.t(etiqueta, sql, ok)   ejecuta el SQL e imprime "OK" o "FALLO":
--       ok = true  → debe ejecutarse y afectar/devolver al menos una fila
--       ok = false → debe ser rechazado o devolver 0 filas
-- ==============================================================================
\set QUIET on
\pset footer off
\pset tuples_only on

CREATE FUNCTION pg_temp.as_user(u uuid) RETURNS void LANGUAGE sql AS
  $$ SELECT set_config('request.jwt.claim.sub', coalesce(u::text, ''), false) $$;

CREATE FUNCTION pg_temp.t(label text, q text, should_pass boolean) RETURNS text LANGUAGE plpgsql AS $$
DECLARE n bigint;
BEGIN
  EXECUTE q; GET DIAGNOSTICS n = ROW_COUNT;
  IF should_pass AND n > 0 THEN RETURN 'OK    ' || label;
  ELSIF should_pass THEN RETURN 'FALLO ' || label || ' (0 filas)';
  ELSIF n = 0 THEN RETURN 'OK    ' || label || ' -> bloqueado (0 filas)';
  ELSE RETURN 'FALLO ' || label || ' (se permitio: ' || n || ' filas)'; END IF;
EXCEPTION WHEN others THEN
  IF should_pass THEN RETURN 'FALLO ' || label || ' -> ' || SQLERRM;
  ELSE RETURN 'OK    ' || label || '  ->  "' || SQLERRM || '"'; END IF;
END $$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA pg_temp TO authenticated, anon;
