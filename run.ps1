param([int]$Port = 8010)

$root = $PSScriptRoot
$backend = Join-Path $root "nisar-app\.venv\Scripts\python.exe"
$pipeline = Join-Path $root ".venv\Scripts\python.exe"

if (-not (Test-Path $backend)) {
    Write-Host "Falta nisar-app\.venv. Ejecuta .\setup.ps1 primero."
    exit 1
}
if (-not (Test-Path $pipeline)) {
    Write-Host "Falta .venv del pipeline. Ejecuta .\setup.ps1 primero."
    exit 1
}

function Leer-Env([string]$ruta) {
    $valores = @{}
    if (Test-Path -LiteralPath $ruta) {
        # configurar.ps1 escribe el .env en UTF-8 sin BOM.
        foreach ($linea in Get-Content -LiteralPath $ruta -Encoding UTF8) {
            $limpia = $linea.Trim()
            if (-not $limpia -or $limpia.StartsWith("#") -or -not $limpia.Contains("=")) {
                continue
            }
            $clave, $valor = $limpia.Split("=", 2)
            $valores[$clave.Trim()] = $valor.Trim().Trim('"').Trim("'")
        }
    }
    return $valores
}

$config = Leer-Env (Join-Path $root ".env")
if ($config["NISAR_DATA"]) {
    $env:CLIMATE3D_NISAR = $config["NISAR_DATA"] -replace '/', '\'
}
if ($config["NISAR_MEDIA"]) {
    $env:NISAR_MEDIA = $config["NISAR_MEDIA"] -replace '/', '\'
}
if (-not $PSBoundParameters.ContainsKey("Port") -and $config["PORT"]) {
    try { $Port = [int]$config["PORT"] } catch { }
}

if (-not $env:CLIMATE3D_PYTHON) {
    $env:CLIMATE3D_PYTHON = $pipeline
}
if (-not $env:CLIMATE3D_NISAR -and (Test-Path "D:\nisar")) {
    $env:CLIMATE3D_NISAR = "D:\nisar"
}
if ($env:NISAR_MEDIA) {
    New-Item -ItemType Directory -Force -Path $env:NISAR_MEDIA | Out-Null
}

Write-Host "NISAR en http://127.0.0.1:$Port"
if ($env:CLIMATE3D_NISAR) { Write-Host "Datos NISAR: $env:CLIMATE3D_NISAR" }
if ($env:NISAR_MEDIA) { Write-Host "Artefactos:  $env:NISAR_MEDIA" }
& $backend -m uvicorn nisar_backend.main:app --app-dir (Join-Path $root "nisar-app") --port $Port
