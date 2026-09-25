<#
.SYNOPSIS
  Restaura un backup generado con backup_db.ps1 (REQ-40).

.DESCRIPTION
  Procedimiento:
    1. Crear un proyecto de Supabase vacío (o usar uno sin datos).
    2. Aplicar en orden las migraciones de supabase/migrations/.
    3. Ejecutar este script: carga los usuarios de Auth y los datos de public.

  La carga se hace en una sola transacción: si algo falla, no se guarda nada.
  Los triggers se desactivan durante la carga para no duplicar auditoría ni
  recrear perfiles. Por seguridad, el script se niega a restaurar sobre una
  base que ya tiene usuarios u ofertas.

.PARAMETER BackupDir
  Carpeta del backup (ej. backups\2026-09-25_1530).

.PARAMETER DbUrl
  Cadena de conexión de la base DESTINO. Si no se indica, se usa la variable de
  entorno SUPABASE_DB_URL o se pide.

.PARAMETER PgBin
  Carpeta con psql.exe. Si no se indica, se usa PG_BIN o el PATH.

.PARAMETER ConfirmHost
  Host destino para confirmar sin escribirlo a mano (debe coincidir exactamente).

.EXAMPLE
  .\scripts\restore_db.ps1 -BackupDir backups\2026-09-25_1530
#>
param(
  [Parameter(Mandatory = $true)][string]$BackupDir,
  [string]$DbUrl = $env:SUPABASE_DB_URL,
  [string]$PgBin = $env:PG_BIN,
  [string]$ConfirmHost
)

$ErrorActionPreference = 'Stop'

function Get-PgTool([string]$Name) {
  if ($PgBin) {
    $path = Join-Path $PgBin "$Name.exe"
    if (Test-Path $path) { return $path }
    throw "No se encontró $Name.exe en '$PgBin'."
  }
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw "No se encontró $Name. Indica la carpeta 'bin' de PostgreSQL con -PgBin o la variable PG_BIN."
}

$psql = Get-PgTool 'psql'

$authFile = Join-Path $BackupDir 'auth.sql'
$dataFile = Join-Path $BackupDir 'data.sql'
foreach ($f in @($authFile, $dataFile)) {
  if (-not (Test-Path $f)) { throw "No existe $f. ¿Es una carpeta de backup válida?" }
}

if (-not $DbUrl) {
  $DbUrl = Read-Host 'Pega la cadena de conexión de la base DESTINO'
}
if (-not $DbUrl) { throw 'Se necesita la cadena de conexión.' }
if ($DbUrl -match '\[|\]|YOUR-PASSWORD') {
  throw 'La cadena tiene corchetes o [YOUR-PASSWORD]: reemplaza todo el marcador, corchetes incluidos, por la contraseña.'
}
# usuario:contraseña@host debe tener una sola "@" (la separadora).
$authority = ($DbUrl -replace '^[a-z]+://', '') -replace '[/?].*$', ''
if (($authority -split '@').Count -gt 2) {
  throw 'La contraseña contiene "@" sin codificar. Escríbela como %40 (o usa una contraseña solo con letras y números).'
}

$dbHost = ($DbUrl -replace '^[a-z]+://[^@]*@', '') -replace '[/?].*$', ''

# 1. Las migraciones deben estar aplicadas y la base debe estar vacía.
$check = & $psql --dbname $DbUrl --tuples-only --no-align --command @"
SELECT CASE
  WHEN to_regclass('public.profiles') IS NULL THEN 'sin-migraciones'
  WHEN (SELECT count(*) FROM public.profiles) + (SELECT count(*) FROM public.offers) > 0 THEN 'con-datos'
  ELSE 'ok'
END;
"@
if ($LASTEXITCODE -ne 0) { throw 'No se pudo conectar a la base destino.' }
$check = "$check".Trim()
if ($check -eq 'sin-migraciones') {
  throw 'La base destino no tiene las tablas. Aplica primero las migraciones de supabase/migrations/.'
}
if ($check -eq 'con-datos') {
  throw 'La base destino ya tiene usuarios u ofertas. Restaura sobre un proyecto vacío.'
}

# 2. Confirmación explícita.
Write-Host "Vas a restaurar '$BackupDir' en: $dbHost" -ForegroundColor Yellow
$manifest = Join-Path $BackupDir 'manifest.txt'
if (Test-Path $manifest) { Get-Content $manifest | ForEach-Object { Write-Host "  $_" } }
$confirm = $ConfirmHost
if (-not $confirm) { $confirm = Read-Host "Escribe el host destino para confirmar ($dbHost)" }
if ($confirm -ne $dbHost) { throw 'Confirmación incorrecta. No se restauró nada.' }

# 3. Carga en una sola transacción, con triggers desactivados.
#    Se vacían antes las tablas de public para quitar filas creadas por las
#    migraciones (ej. la fila por defecto de platform_config).
$truncate = @"
DO `$`$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('TRUNCATE public.%I CASCADE', r.tablename);
  END LOOP;
END `$`$;
"@

Write-Host 'Restaurando...'
& $psql --dbname $DbUrl --single-transaction --set ON_ERROR_STOP=1 --quiet `
  --command 'SET client_min_messages = warning; SET session_replication_role = replica;' `
  --command $truncate `
  --file $authFile `
  --file $dataFile
if ($LASTEXITCODE -ne 0) { throw 'Falló la restauración. La transacción se revirtió: la base quedó como estaba.' }

Write-Host 'Restauración completada. Compara estos conteos con manifest.txt:' -ForegroundColor Green
& $psql --dbname $DbUrl --tuples-only --no-align --command @"
SELECT format('%s.%s: %s', table_schema, table_name,
  (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I.%I', table_schema, table_name), false, true, '')))[1]::text)
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND (table_schema = 'public' OR (table_schema = 'auth' AND table_name IN ('users', 'identities')))
ORDER BY table_schema, table_name;
"@ | ForEach-Object { Write-Host "  $_" }
