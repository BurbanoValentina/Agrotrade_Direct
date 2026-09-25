<#
.SYNOPSIS
  Backup manual de la base de datos de Supabase (REQ-40).

.DESCRIPTION
  Genera backups/AAAA-MM-DD_HHMM/ con:
    schema.sql  Esquema public (referencia; la restauración usa las migraciones)
    data.sql    Datos de todas las tablas de public
    auth.sql    Usuarios de Supabase Auth (auth.users / auth.identities)
    manifest.txt Fecha, origen y conteo de filas para verificar la restauración

  Los backups contienen datos personales: la carpeta backups/ está en
  .gitignore y NUNCA debe subirse al repositorio (es público).

.PARAMETER DbUrl
  Cadena de conexión de Supabase (Dashboard -> Connect -> Session pooler).
  Si no se indica, se usa la variable de entorno SUPABASE_DB_URL o se pide.

.PARAMETER PgBin
  Carpeta con pg_dump.exe y psql.exe (versión 15 o superior). Si no se indica,
  se usa la variable de entorno PG_BIN o el PATH.

.EXAMPLE
  .\scripts\backup_db.ps1
  .\scripts\backup_db.ps1 -PgBin "C:\postgresql\pgsql\bin"
#>
param(
  [string]$DbUrl = $env:SUPABASE_DB_URL,
  [string]$PgBin = $env:PG_BIN,
  [string]$OutDir = (Join-Path $PSScriptRoot '..\backups')
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

function Invoke-PgTool([string]$Tool, [string[]]$Arguments, [string]$Step) {
  & $Tool @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Falló el paso: $Step (código $LASTEXITCODE)." }
}

$pgDump = Get-PgTool 'pg_dump'
$psql = Get-PgTool 'psql'

if (-not $DbUrl) {
  $DbUrl = Read-Host 'Pega la cadena de conexión de Supabase (Session pooler)'
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

# Host sin credenciales, para mostrarlo y dejarlo en el manifiesto.
$dbHost = ($DbUrl -replace '^[a-z]+://[^@]*@', '') -replace '[/?].*$', ''

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$target = Join-Path $OutDir $stamp
New-Item -ItemType Directory -Force $target | Out-Null
$target = (Resolve-Path $target).Path

Write-Host "Backup de $dbHost -> $target"

try {
  Write-Host '  1/4 Esquema public...'
  Invoke-PgTool $pgDump @('--dbname', $DbUrl, '--schema', 'public', '--schema-only', '--no-owner',
    '--file', (Join-Path $target 'schema.sql')) 'esquema'

  Write-Host '  2/4 Datos de public...'
  Invoke-PgTool $pgDump @('--dbname', $DbUrl, '--schema', 'public', '--data-only', '--no-owner',
    '--file', (Join-Path $target 'data.sql')) 'datos'

  Write-Host '  3/4 Usuarios de Auth...'
  Invoke-PgTool $pgDump @('--dbname', $DbUrl, '--data-only', '--no-owner',
    '--table', 'auth.users', '--table', 'auth.identities',
    '--file', (Join-Path $target 'auth.sql')) 'usuarios de auth'

  Write-Host '  4/4 Conteo de filas...'
  $countQuery = @"
SELECT format('%s.%s: %s', table_schema, table_name,
  (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I.%I', table_schema, table_name), false, true, '')))[1]::text)
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND (table_schema = 'public' OR (table_schema = 'auth' AND table_name IN ('users', 'identities')))
ORDER BY table_schema, table_name;
"@
  $counts = & $psql --dbname $DbUrl --tuples-only --no-align --command $countQuery
  if ($LASTEXITCODE -ne 0) { throw 'Falló el conteo de filas.' }
  $pgVersion = & $pgDump --version

  $manifest = @(
    "Backup AgroTrade Direct (REQ-40)",
    "Fecha:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
    "Origen:   $dbHost",
    "pg_dump:  $pgVersion",
    "",
    "Filas por tabla:"
  ) + ($counts | ForEach-Object { "  $_" })
  $manifest | Set-Content -Encoding utf8 (Join-Path $target 'manifest.txt')
} catch {
  # No dejar backups a medias: se borra la carpeta y se relanza el error.
  Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue
  throw
}

Write-Host ''
Write-Host 'Backup completado:' -ForegroundColor Green
$counts | ForEach-Object { Write-Host "  $_" }
Write-Host ''
Write-Host 'Guárdalo en un lugar seguro (contiene datos personales). No lo subas al repositorio.' -ForegroundColor Yellow
