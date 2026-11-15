@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title NISAR

rem ===========================================================
rem  Uso:
rem    ARRANCAR.bat           modo local (solo necesita Python)
rem    ARRANCAR.bat docker    modo Docker (necesita Docker Desktop)
rem ===========================================================

if /I "%~1"=="docker" goto docker
goto local


rem -----------------------------------------------------------
rem  MODO LOCAL
rem -----------------------------------------------------------
:local
echo ==========================================
echo    NISAR - instalar y arrancar (local)
echo ==========================================
echo.

echo [1/4] Verificando Python o uv...
where uv >nul 2>&1
if not errorlevel 1 goto python_ok
where py >nul 2>&1
if not errorlevel 1 goto python_ok
where python >nul 2>&1
if not errorlevel 1 goto python_ok

echo.
echo [x] No encontre ni Python ni uv.
echo.
echo     1. Se va a abrir la pagina de descarga.
echo     2. Instala Python 3.12 o superior.
echo     3. Marca "Add python.exe to PATH" en el instalador.
echo     4. Volve a ejecutar este archivo.
echo.
echo     Alternativa mas rapida: winget install astral-sh.uv
echo.
pause
start "" "https://www.python.org/downloads/"
exit /b 1

:python_ok
echo       ok.
echo.

echo [2/4] Preparando los entornos (la primera vez tarda unos minutos)...
if not exist "%~dp0.venv\Scripts\python.exe" goto instalar
if not exist "%~dp0nisar-app\.venv\Scripts\python.exe" goto instalar
echo       ok, ya estaban creados.
goto entornos_ok

:instalar
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
if errorlevel 1 goto fallo

:entornos_ok
echo.

echo [3/4] Configurando carpeta de datos, claves y puerto...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0configurar.ps1" -Modo Local
if errorlevel 1 goto fallo
echo.

echo [4/4] Arrancando el servidor y abriendo el navegador...
start "NISAR - servidor" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
set "PORT=8010"
if exist "%~dp0.env" (
    for /f "tokens=2 delims==" %%p in ('findstr /b "PORT=" "%~dp0.env" 2^>nul') do set "PORT=%%p"
)
timeout /t 8 /nobreak >nul
start "" "http://127.0.0.1:%PORT%"

echo.
echo ==========================================
echo    Listo. La app queda corriendo.
echo    Direccion: http://127.0.0.1:%PORT%
echo.
echo    Para apagarla: doble clic en APAGAR.bat
echo    Consola del servidor: ventana "NISAR - servidor".
echo ==========================================
echo.
pause
exit /b 0


rem -----------------------------------------------------------
rem  MODO DOCKER
rem -----------------------------------------------------------
:docker
echo ==========================================
echo    NISAR - instalar y arrancar (Docker)
echo ==========================================
echo.

where docker >nul 2>&1
if errorlevel 1 goto sin_docker

echo [1/4] Verificando Docker...
docker info >nul 2>&1
if not errorlevel 1 goto docker_ok

echo       Docker esta apagado. Arrancandolo...
docker desktop start >nul 2>&1
if errorlevel 1 start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"

set /a n=0
:esperar
timeout /t 5 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto docker_ok
set /a n+=1
if !n! LSS 36 goto esperar

echo.
echo [x] Docker no respondio en 3 minutos.
echo     Abri Docker Desktop a mano, espera a que diga "Engine running"
echo     y volve a ejecutar este archivo.
echo.
pause
exit /b 1

:docker_ok
echo       ok, Docker responde.
echo.

echo [2/4] Verificando la aplicacion...
docker image inspect nisar-app:local >nul 2>&1
if not errorlevel 1 goto imagen_ok
echo       La primera vez se compila la imagen (tarda unos minutos).
:imagen_ok
echo.

echo [3/4] Configurando la carpeta de datos y las credenciales...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0configurar.ps1" -Modo Docker
if errorlevel 1 goto fallo

echo.
echo [4/4] Abriendo el navegador...
set "PORT=8010"
if exist "%~dp0.env" (
    for /f "tokens=2 delims==" %%p in ('findstr /b "PORT=" "%~dp0.env" 2^>nul') do set "PORT=%%p"
)
start "" "http://127.0.0.1:%PORT%"

echo.
echo ==========================================
echo    Listo. La app queda corriendo.
echo.
echo    Para apagarla: doble clic en APAGAR.bat
echo ==========================================
echo.
pause
exit /b 0

:sin_docker
echo [x] Docker Desktop no esta instalado.
echo.
echo     No hace falta para usar la app: ejecuta este archivo
echo     SIN argumentos y arranca en modo local (solo Python).
echo.
echo     Si igual queres Docker:
echo       1. Se va a abrir la pagina de descarga.
echo       2. Instalalo con las opciones por defecto.
echo       3. Si te pide reiniciar, reinicia.
echo       4. Volve a ejecutar: ARRANCAR.bat docker
echo.
pause
start "" "https://www.docker.com/products/docker-desktop/"
exit /b 1

:fallo
echo.
echo [x] Algo fallo.
echo     Copia el texto de arriba y abri un issue en el repositorio.
echo.
pause
exit /b 1
