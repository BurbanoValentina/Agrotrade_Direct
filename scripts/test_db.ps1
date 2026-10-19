<#
.SYNOPSIS
  Prueba las migraciones de Supabase en un PostgreSQL local temporal (REQ-25).

.DESCRIPTION
  1. Crea un PostgreSQL temporal y simula Supabase (supabase/tests/00_stub_supabase.sql).
  2. Aplica todas las migraciones de supabase/migrations/ DOS veces (deben poder repetirse).
  3. Ejecuta cada supabase/tests/test_*.sql sobre una base limpia y cuenta OK / FALLO.
  4. Borra la base temporal.

  No toca el proyecto real de Supabase. Termina con código 1 si algo falla.

.PARAMETER PgBin
  Carpeta 'bin' de PostgreSQL 15+ (initdb, pg_ctl, psql). Si no se indica, usa
  la variable PG_BIN o el PATH.

.PARAMETER Filter
  Ejecuta solo las pruebas cuyo nombre contenga este texto (ej. "privacy").

.EXAMPLE
  .\scripts\test_db.ps1 -PgBin "C:\postgresql\pgsql\bin"
#>
param(
  [string]$PgBin = $env:PG_BIN,
  [string]$Filter = '',
  [int]$Port = 54329,
  # Muestra cada escenario (OK / FALLO) y no solo el resumen.
  [switch]$Detalle
)

# 'Continue': psql escribe avisos (NOTICE) en stderr y PowerShell 5.1 los
# volvería errores fatales; los fallos se detectan por el código de salida.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$env:PGCLIENTENCODING = 'UTF8'

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

$initdb = Get-PgTool 'initdb'
$pgctl = Get-PgTool 'pg_ctl'
$psql = Get-PgTool 'psql'

$root = Split-Path $PSScriptRoot -Parent
$migrations = Get-ChildItem (Join-Path $root 'supabase\migrations') -Filter '*.sql' | Sort-Object Name
$testsDir = Join-Path $root 'supabase\tests'
$stub = Join-Path $testsDir '00_stub_supabase.sql'
$helpers = Join-Path $testsDir '01_helpers.sql'
$tests = Get-ChildItem $testsDir -Filter 'test_*.sql' | Sort-Object Name |
  Where-Object { $_.Name -like "*$Filter*" }

$data = Join-Path ([IO.Path]::GetTempPath()) ("agrotrade_test_db_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))

function Invoke-Psql([string]$Db, [string[]]$Files, [switch]$StopOnError) {
  $psqlArgs = @('-h', 'localhost', '-p', $Port, '-U', 'postgres', '-d', $Db, '-q', '-X')
  if ($StopOnError) { $psqlArgs += @('-v', 'ON_ERROR_STOP=1') }
  foreach ($f in $Files) { $psqlArgs += @('-f', $f) }
  $out = & $psql @psqlArgs 2>&1 | ForEach-Object { "$_" }
  return , @($out, $LASTEXITCODE)
}

function New-TestDatabase([string]$Name, [int]$Passes = 1) {
  & $psql -h localhost -p $Port -U postgres -d postgres -q -X -c "DROP DATABASE IF EXISTS $Name" -c "CREATE DATABASE $Name" 2>&1 | Out-Null
  $r = Invoke-Psql $Name @($stub) -StopOnError
  if ($r[1] -ne 0) { throw "Falló la simulación de Supabase: $($r[0] -join "`n")" }
  for ($p = 1; $p -le $Passes; $p++) {
    foreach ($m in $migrations) {
      $r = Invoke-Psql $Name @($m.FullName) -StopOnError
      if ($r[1] -ne 0) {
        throw "La migración $($m.Name) falló (pasada $p):`n$(($r[0] | Where-Object { $_ -match 'ERROR' }) -join "`n")"
      }
    }
  }
}

$failed = 0
try {
  Write-Host "PostgreSQL temporal en $data (puerto $Port)..."
  & $initdb -D $data -U postgres -A trust -E UTF8 --locale=C 2>&1 | Out-Null
  # pg_ctl deja corriendo el servidor: su salida se manda a NUL desde cmd para
  # que PowerShell no se quede esperando a que se cierre.
  cmd /c "`"$pgctl`" -D `"$data`" -o `"-p $Port -c lc_messages=C`" -l `"$data\server.log`" -w start > NUL 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "No arrancó PostgreSQL (¿puerto $Port ocupado?)." }
  & $psql -h localhost -p $Port -U postgres -d postgres -q -X -c "CREATE ROLE anon NOLOGIN" -c "CREATE ROLE authenticated NOLOGIN" -c "CREATE ROLE service_role NOLOGIN BYPASSRLS" 2>&1 | Out-Null

  Write-Host "Migraciones ($($migrations.Count)) aplicadas dos veces..." -NoNewline
  New-TestDatabase 'agrotrade_idempotencia' -Passes 2
  Write-Host ' OK' -ForegroundColor Green

  $summary = @()
  foreach ($test in $tests) {
    New-TestDatabase 'agrotrade_test'
    $r = Invoke-Psql 'agrotrade_test' @($helpers, $test.FullName)
    $lines = $r[0]
    $ok = @($lines | Where-Object { $_ -match '^\s*OK\s' }).Count
    $bad = @($lines | Where-Object { $_ -match 'FALLO' -or $_ -match 'ERROR' })
    $summary += [pscustomobject]@{ Prueba = $test.BaseName; OK = $ok; Fallos = $bad.Count }
    if ($Detalle) {
      Write-Host "`n== $($test.Name)" -ForegroundColor Cyan
      $lines | Where-Object { $_.Trim() -and $_ -notmatch 'NOTICE' } | ForEach-Object { Write-Host "  $($_.TrimEnd())" }
    }
    if ($bad.Count -gt 0) {
      $failed += $bad.Count
      Write-Host "`n== $($test.Name)" -ForegroundColor Red
      $bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
  }

  Write-Host ''
  $summary | Format-Table -AutoSize | Out-String | Write-Host
  $total = ($summary | Measure-Object OK -Sum).Sum
  if ($failed -eq 0) {
    Write-Host "Todas las pruebas pasaron: $total escenarios OK." -ForegroundColor Green
  } else {
    Write-Host "$failed fallo(s). Revisa los mensajes en rojo." -ForegroundColor Red
  }
} finally {
  cmd /c "`"$pgctl`" -D `"$data`" -m fast -w stop > NUL 2>&1"
  Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { exit 1 }
