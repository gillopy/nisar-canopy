$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$app  = Join-Path $root "nisar-app"

function Ok([string]$mensaje) { Write-Host "  ok  $mensaje" -ForegroundColor Green }
function Aviso([string]$mensaje) { Write-Host "  !   $mensaje" -ForegroundColor Yellow }

# --- Camino principal: uv -----------------------------------------------------
# uv resuelve desde pyproject.toml + uv.lock, crea el .venv si falta y no
# necesita tener pip dentro. Es mucho mas rapido que pip en una instalacion limpia.
$uvExe = $null
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) { $uvExe = $uvCmd.Source }

if ($uvExe) {
    Write-Host "uv: $(& $uvExe --version)"

    Write-Host "Sincronizando el pipeline (raiz)..."
    & $uvExe sync --directory $root
    if ($LASTEXITCODE -ne 0) { throw "uv sync fallo en el pipeline. Mira la salida de arriba." }
    Ok "pipeline listo en .venv"

    Write-Host "Sincronizando el backend (nisar-app)..."
    & $uvExe sync --directory $app
    if ($LASTEXITCODE -ne 0) { throw "uv sync fallo en el backend. Mira la salida de arriba." }
    Ok "backend listo en nisar-app\.venv"
}
else {
    # --- Respaldo: venv + pip -------------------------------------------------
    Aviso "uv no esta instalado: se usa venv + pip (mas lento)."
    Write-Host "       Para instalarlo:  winget install astral-sh.uv"
    Write-Host ""

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
        throw "No encontre Python. Instala Python 3.12+ y volve a intentar."
    }

    # Verificar la version de verdad: "where python" tambien encuentra el alias
    # falso de la Microsoft Store, que no es un interprete.
    & $pythonExe @pythonArgs -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 12) else 1)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Python 3.12+ es obligatorio (numpy 2.5 no soporta 3.11). Version encontrada: $(& $pythonExe @pythonArgs --version 2>&1)"
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

    $backend = Ensure-Venv (Join-Path $app ".venv")
    Write-Host "Instalando backend..."
    & $backend -m pip install --upgrade pip
    & $backend -m pip install -r (Join-Path $app "requirements.txt")
}

# --- Comun a los dos caminos --------------------------------------------------
$envFile = Join-Path $app ".env"
if (-not (Test-Path $envFile)) {
    Copy-Item (Join-Path $app "env.example") $envFile
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
