$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Preferir 3.13/3.14: son las versiones con las que esta probado el pipeline.
$launcher = @("python")
if (Get-Command py -ErrorAction SilentlyContinue) {
    foreach ($version in @("-3.13", "-3.14")) {
        & py $version -c "import sys" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $launcher = @("py", $version)
            break
        }
    }
}
$pythonExe = $launcher[0]
$pythonArgs = @()
if ($launcher.Length -gt 1) {
    $pythonArgs = $launcher[1..($launcher.Length - 1)]
}
if (-not (Get-Command $pythonExe -ErrorAction SilentlyContinue)) {
    throw "No encontre Python. Instala Python 3.11+ y volve a intentar."
}

function Ensure-Venv([string]$path) {
    $exe = Join-Path $path "Scripts\python.exe"
    if (-not (Test-Path $exe)) {
        Write-Host "Creando $path ..."
        & $pythonExe @pythonArgs -m venv $path
    }
    return $exe
}

$pipeline = Ensure-Venv (Join-Path $root ".venv")
Write-Host "Instalando pipeline..."
& $pipeline -m pip install --upgrade pip
& $pipeline -m pip install -r (Join-Path $root "requirements-pipeline.txt")

$backend = Ensure-Venv (Join-Path $root "nisar-app\.venv")
Write-Host "Instalando backend..."
& $backend -m pip install --upgrade pip
& $backend -m pip install -r (Join-Path $root "nisar-app\requirements.txt")

$envFile = Join-Path $root "nisar-app\.env"
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $root "nisar-app\env.example") $envFile
    Write-Host "Cree nisar-app\.env: completa EARTHDATA_USER y EARTHDATA_PASSWORD."
}

$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm) {
    Write-Host "Frontend ya compilado en nisar-app\frontend\dist."
    Write-Host "Para desarrollo: cd nisar-app\frontend; npm install; npm run dev"
} else {
    Write-Host "Sin npm: se usa el frontend ya compilado en nisar-app\frontend\dist."
}

Write-Host ""
Write-Host "Listo. Ejecuta .\run.ps1 y abri http://127.0.0.1:8010"
