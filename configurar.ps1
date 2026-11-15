param(
    [ValidateSet("Docker", "Local")]
    [string]$Modo = "Local",
    [string]$DataDir,
    [string]$MediaDir,
    [string]$EarthdataUser,
    [string]$EarthdataPassword,
    [string]$FirmsKey,
    [int]$Port = 8010,
    [switch]$SoloConfigurar
)

$ErrorActionPreference = "Stop"
$raiz = $PSScriptRoot
Set-Location -LiteralPath $raiz

function Fallar([string]$mensaje) {
    Write-Host "`n  x  $mensaje" -ForegroundColor Red
    exit 1
}
function Ok([string]$mensaje) { Write-Host "  ok  $mensaje" -ForegroundColor Green }
function Aviso([string]$mensaje) { Write-Host "  !  $mensaje" -ForegroundColor Yellow }
function Paso([string]$mensaje) { Write-Host "`n$mensaje" -ForegroundColor Cyan }

function Preguntar([string]$texto, [string]$porDefecto) {
    # En una consola no interactiva `Read-Host` tira error: devolvemos el default.
    try { $valor = Read-Host "$texto [$porDefecto]" } catch { return $porDefecto }
    if ([string]::IsNullOrWhiteSpace($valor)) { return $porDefecto }
    return $valor.Trim()
}

function ValorEnv([string]$valor) {
    # Compose corta el valor en un `#` y se come los espacios de los bordes.
    if ($valor -match '[\s#]') { return '"' + ($valor -replace '"', '\"') + '"' }
    return $valor
}

function Escribir([string]$ruta, [string]$contenido) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ruta, $contenido, $utf8)
}

function Leer-Env([string]$ruta) {
    $valores = @{}
    if (Test-Path -LiteralPath $ruta) {
        # El .env se escribe UTF-8 sin BOM: sin -Encoding UTF8, PS 5.1 lo lee
        # como ANSI y corrompe las rutas con acentos.
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

function PuertoOcupado([int]$puerto) {
    return [bool](Get-NetTCPConnection -LocalPort $puerto -State Listen -ErrorAction SilentlyContinue)
}

function DuenoPuerto([int]$puerto) {
    $conexion = Get-NetTCPConnection -LocalPort $puerto -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $conexion) { return "desconocido" }
    $proceso = Get-Process -Id $conexion.OwningProcess -ErrorAction SilentlyContinue
    if ($proceso) { return "PID $($conexion.OwningProcess) ($($proceso.ProcessName))" }
    return "PID $($conexion.OwningProcess)"
}

$envRaiz = Join-Path $raiz ".env"
$envApp = Join-Path $raiz "nisar-app\.env"
$previo = Leer-Env $envRaiz
$appActual = Leer-Env $envApp

# El puerto elegido la vez anterior manda, salvo que se pase -Port a mano.
if (-not $PSBoundParameters.ContainsKey("Port") -and $previo["PORT"]) {
    try { $Port = [int]$previo["PORT"] } catch { }
}


Paso "[1/5] Docker"
if ($SoloConfigurar) {
    Ok "solo configuracion: no se verifica ni se levanta Docker."
} elseif ($Modo -eq "Local") {
    Ok "modo local: no hace falta Docker."
} else {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Fallar "no encontre 'docker'. Instala Docker Desktop o usa ARRANCAR-LOCAL.bat."
    }
    & docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Fallar "Docker esta instalado pero el daemon no responde. Abri Docker Desktop y espera a que arranque."
    }
    & docker compose version 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Fallar "falta el plugin 'docker compose'. Actualiza Docker Desktop."
    }
    Ok "Docker responde."
}


Paso "[2/5] Carpeta de datos (los .h5 y los artefactos)"
$sugerida = if ($previo["NISAR_DATA"]) {
    $previo["NISAR_DATA"] -replace '/', '\'
} elseif (Test-Path -LiteralPath "D:\") {
    "D:\nisar"
} else {
    Join-Path $env:USERPROFILE "nisar-data"
}

if ([string]::IsNullOrWhiteSpace($DataDir)) {
    $DataDir = Preguntar "  Donde guardamos los .h5 NISAR (cada escena ronda 2 GB)?" $sugerida
}
$DataDir = $DataDir.Trim().Trim('"').Trim("'")
$DataDir = ($DataDir -replace '\\', '/').TrimEnd('/')
if ([string]::IsNullOrWhiteSpace($DataDir)) {
    Fallar "la carpeta de datos quedo vacia."
}
if ($DataDir.StartsWith('//')) {
    Fallar "no puedo montar una ruta de red como volumen ('$DataDir'). Usa un disco local y copia los datos ahi."
}
foreach ($od in @($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer)) {
    if ([string]::IsNullOrWhiteSpace($od)) { continue }
    $odPosix = ($od -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
    $destino = $DataDir.ToLowerInvariant()
    if ($destino -eq $odPosix -or $destino.StartsWith($odPosix + '/')) {
        Fallar "esa carpeta esta dentro de OneDrive: sincronizar varios GB lo traba. Elegi una carpeta fuera de la nube."
    }
}
# Respaldo por si la carpeta esta redirigida y las variables de OneDrive no lo dicen:
# un segmento exacto, no una subcadena (D:/onedrive-datos es valido).
if ($DataDir -match '(?i)/(onedrive)(/|$)') {
    Fallar "esa carpeta esta dentro de OneDrive. Elegi una carpeta fuera de la nube: son varios GB."
}

$rutaWin = $DataDir -replace '/', '\'
if (Test-Path -LiteralPath $rutaWin) {
    Ok "usa $rutaWin (ya existia)"
} else {
    New-Item -ItemType Directory -Path $rutaWin -Force -ErrorAction SilentlyContinue | Out-Null
    if (-not (Test-Path -LiteralPath $rutaWin)) {
        Fallar "no pude crear '$rutaWin'. Revisa los permisos."
    }
    Ok "cree $rutaWin"
}

$prueba = Join-Path $rutaWin ('.escritura-' + [guid]::NewGuid().ToString('N'))
try {
    Set-Content -LiteralPath $prueba -Value 'ok' -Encoding ASCII -ErrorAction Stop
    Remove-Item -LiteralPath $prueba -Force -ErrorAction Stop
} catch {
    Fallar "no puedo escribir en '$rutaWin'. Elegi otra carpeta o dale permiso."
}
Ok "la carpeta es escribible."

if ([string]::IsNullOrWhiteSpace($MediaDir)) {
    # Si ya habia una carpeta de artefactos, se respeta: ahi estan los jobs viejos.
    if ($previo["NISAR_MEDIA"]) {
        $MediaDir = $previo["NISAR_MEDIA"]
    } else {
        $MediaDir = "$DataDir/media"
    }
}
$MediaDir = $MediaDir.Trim().Trim('"').Trim("'")
$MediaDir = ($MediaDir -replace '\\', '/').TrimEnd('/')
$rutaMedia = $MediaDir -replace '/', '\'
New-Item -ItemType Directory -Path $rutaMedia -Force -ErrorAction SilentlyContinue | Out-Null
if (-not (Test-Path -LiteralPath $rutaMedia)) {
    Fallar "no pude crear la carpeta de artefactos '$rutaMedia'."
}
Ok "artefactos en $rutaMedia"

$unidad = Split-Path -Qualifier $rutaWin
if ($unidad) {
    $disco = Get-PSDrive -Name $unidad.TrimEnd(':') -ErrorAction SilentlyContinue
    if ($disco -and $disco.Free -gt 0) {
        $libres = [math]::Round($disco.Free / 1GB, 1)
        if ($libres -lt 20) {
            Aviso ("quedan {0} GB libres: cada escena ronda 2 GB." -f $libres)
        } else {
            Ok ("espacio libre: {0} GB" -f $libres)
        }
    }
}


Paso "[3/5] Credenciales (las dos son gratuitas)"
if (-not $EarthdataUser) { $EarthdataUser = $appActual["EARTHDATA_USER"] }
if (-not $EarthdataPassword) { $EarthdataPassword = $appActual["EARTHDATA_PASSWORD"] }
if (-not $FirmsKey) { $FirmsKey = $appActual["FIRMS_MAP_KEY"] }

if ($EarthdataUser) {
    Ok "Earthdata: $EarthdataUser (baja los .h5)"
} else {
    Aviso "Earthdata: sin configurar (sin cuenta no se bajan los .h5)"
}
if ($FirmsKey) {
    Ok "FIRMS MAP_KEY: cargada (focos de calor del producto incendio)"
} else {
    Aviso "FIRMS MAP_KEY: sin configurar (solo la necesita incendio + FIRMS)"
}

if (-not $SoloConfigurar -and -not [Console]::IsInputRedirected) {
    Write-Host "  Earthdata: cuenta gratuita en https://urs.earthdata.nasa.gov/"
    Write-Host "  FIRMS MAP_KEY: gratis en https://firms.modaps.eosdis.nasa.gov/api/map_key/"
    # Sin cuenta, el default es cargarla; si ya esta, no se insiste.
    $porDefecto = if ([string]::IsNullOrWhiteSpace($EarthdataUser)) { "S" } else { "N" }
    $cargar = Preguntar "  Cargar o actualizar credenciales ahora? (s/N)" $porDefecto
    if ($cargar -match '^(s|si|y|yes)$') {
        $EarthdataUser = Preguntar "  EARTHDATA_USER (Enter para dejar '$EarthdataUser')" $EarthdataUser
        if (-not [string]::IsNullOrWhiteSpace($EarthdataUser)) {
            $pista = if ($EarthdataPassword) { "Enter para conservar la actual" } else { "obligatoria" }
            try {
                $segura = Read-Host "  EARTHDATA_PASSWORD ($pista)" -AsSecureString
                $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segura)
                $nueva = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                if (-not [string]::IsNullOrWhiteSpace($nueva)) {
                    $EarthdataPassword = $nueva
                }
            } catch {
                # Consola no interactiva: se conserva la que ya estaba.
            }
        }
        $FirmsKey = Preguntar "  FIRMS_MAP_KEY (opcional, Enter para dejar '$FirmsKey')" $FirmsKey
    }
}


Paso "[4/5] Puerto y configuracion (.env)"
if (-not $SoloConfigurar -and (PuertoOcupado $Port)) {
    $nuestro = $false
    if ($Modo -eq "Docker") {
        $servicios = & docker compose ps --status running --services 2>$null
        $nuestro = $servicios -contains "app"
    }
    if ($nuestro) {
        Ok "el puerto $Port lo usa el contenedor NISAR: se recrea con la nueva configuracion."
    } else {
        $intentos = 0
        while ((PuertoOcupado $Port) -and $intentos -lt 3) {
            Aviso "el puerto $Port esta ocupado por $(DuenoPuerto $Port)."
            $elegido = Preguntar "  Elegi otro puerto" "8011"
            try { $Port = [int]$elegido } catch { $Port = 8011 }
            $intentos += 1
        }
        if (PuertoOcupado $Port) {
            Fallar "el puerto $Port sigue ocupado por $(DuenoPuerto $Port). Cerra ese proceso o elegi otro."
        }
    }
}

$lineas = @(
    '# Generado por configurar.ps1. Ver env.example para el detalle de cada variable.',
    '',
    ('NISAR_DATA=' + (ValorEnv $DataDir)),
    ('NISAR_MEDIA=' + (ValorEnv $MediaDir)),
    ('PORT=' + $Port)
)
Escribir $envRaiz ((($lineas -join "`r`n") + "`r`n"))
Ok "escribi $envRaiz"

Escribir $envApp ("EARTHDATA_USER=$(ValorEnv $EarthdataUser)`r`nEARTHDATA_PASSWORD=$(ValorEnv $EarthdataPassword)`r`nFIRMS_MAP_KEY=$(ValorEnv $FirmsKey)`r`n")
Ok "escribi $envApp"

if ($Modo -eq "Docker" -and -not $SoloConfigurar) {
    & docker compose config --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Fallar 'docker-compose.yml no valida con el .env generado. Corre "docker compose config" para ver el detalle.'
    }
    Ok "la configuracion de compose es valida."
}

if ($SoloConfigurar) {
    $siguiente = if ($Modo -eq "Docker") { "docker compose up -d" } else { ".\run.ps1" }
    Write-Host "`nListo: configure .env. Para levantar la app: $siguiente" -ForegroundColor Green
    exit 0
}
if ($Modo -ne "Docker") {
    Write-Host "`nListo. Para arrancar en modo local: .\run.ps1" -ForegroundColor Green
    exit 0
}


Paso "[5/5] Levantando la app (la primera vez compila: tarda varios minutos)"
& docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Fallar "el build o el arranque fallo: mira la salida de arriba."
}

$url = "http://127.0.0.1:$Port"
$limite = (Get-Date).AddMinutes(6)
$salud = $null
Write-Host "  esperando a que la API responda..."
while ((Get-Date) -lt $limite) {
    try {
        $salud = Invoke-RestMethod -Uri "$url/api/health" -TimeoutSec 4 -ErrorAction Stop
        if ($salud.ok) { break }
    } catch {
        $salud = $null
    }
    Start-Sleep -Seconds 3
}

if (-not $salud) {
    & docker compose logs --tail 40 app
    Fallar "la app no respondio en 6 minutos. Mira los logs de arriba."
}
Ok "la API responde."

Write-Host ""
Write-Host "  Listo. Abri esta direccion:" -ForegroundColor Green
Write-Host "    $url" -ForegroundColor White
if (-not $salud.nisar_root_exists) {
    Aviso "la carpeta NISAR no se ve desde el contenedor ($($salud.nisar_root)). Revisa NISAR_DATA en .env."
}
if (-not $salud.repo_ready) {
    Aviso "el pipeline no quedo listo (repo_ready=false). Mira 'docker compose logs app'."
}
if (-not $salud.earthdata_configured) {
    Aviso "Earthdata sin configurar: los .h5 no se van a poder bajar."
}
Write-Host ("  datos:      {0}" -f $rutaWin)
Write-Host ("  artefactos: {0}" -f $rutaMedia)
Write-Host "  Para apagarla: APAGAR.bat"
