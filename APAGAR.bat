@echo off
setlocal
cd /d "%~dp0"
title NISAR - apagar

set "PORT=8010"
if exist "%~dp0.env" (
    for /f "tokens=2 delims==" %%p in ('findstr /b "PORT=" "%~dp0.env" 2^>nul') do set "PORT=%%p"
)

rem 1) Si hay un contenedor, se baja (no hace nada si no existe).
where docker >nul 2>&1
if errorlevel 1 goto local
docker info >nul 2>&1
if errorlevel 1 goto local
docker compose down 2>nul

rem 2) Si quedo algo escuchando en el puerto, se corta.
:local
echo Apagando lo que este usando el puerto %PORT%...
powershell -NoProfile -Command "$c = Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue; foreach ($x in $c) { Stop-Process -Id $x.OwningProcess -Force -ErrorAction SilentlyContinue }"

:fin
echo.
echo Listo. Los datos y los artefactos no se borraron.
echo.
pause
