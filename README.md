# NISAR Canopy

Consola abierta para la misión **NISAR** (NASA-ISRO Synthetic Aperture Radar):
buscás escenas sobre un mapa, bajás el producto y corrés el análisis de cambio que elijas.
Backend FastAPI, frontend React + Leaflet y un pipeline de radar en Python.

Compitió en el **NASA Space Apps Challenge 2026**, reto *Dancing with the SARs*.

> **In English (short):** NISAR Canopy is an open-source console for the NASA-ISRO NISAR
> radar mission. Draw a box on a map, browse the ASF archive, and run the analysis you pick:
> GCOV change detection, 200 m soil moisture (SME2) or 12-day interferometry (GUNW). Every
> run leaves reproducible artifacts and its exact command plan. FastAPI + React; clone the
> repo and run `ARRANCAR.bat` (Windows) to get it working.

## Qué hace

Dibujás una caja sobre el mapa y la app consulta el archivo de ASF para devolver las escenas
NISAR que la cruzan, con browse y fechas. Sobre la escena elegida:

| Producto | Análisis |
| --- | --- |
| **GCOV** | recorte, RVI, cambio, serie temporal, GeoTIFF, agua, incendio, fusión óptica |
| **SME2** | humedad del suelo a 200 m (DSG, PMI, TSR) y comparación entre los tres |
| **GUNW** | coherencia y fase envuelta/desenvuelta del par de 12 días |

Cada corrida queda en un panel de trabajos con historial, log, imágenes, JSON y GeoTIFF. El
log guarda el plan exacto de comandos: un resultado se puede reproducir, no es una captura
de pantalla.

Con la verificación **Sentinel-2** activa, el análisis de cambio escribe además un panel de
**NDVI, NDBI y NDWI** (antes, después y delta) sobre la misma grilla del radar, así se puede
comparar la firma óptica con la caída de HV píxel a píxel.

## Caché de Sentinel-2

Las lecturas ópticas son remotas y caras: cada ítem son 3 aperturas (5 si se piden los
índices). El compuesto se guarda en disco y se reutiliza tal cual.

- **Ubicación**: `NISAR_S2_CACHE`; si no está, `<NISAR_MEDIA>/cache/s2`; si no, el temporal
  del sistema. En la app queda junto a los artefactos.
- **Clave**: caja, fecha, resolución, grilla de destino, bandas y **los ids de los ítems**.
  Si cambiás `--nubes`, `--dias` o `--max-items`, cambia la búsqueda y se recalcula: nunca
  devuelve un compuesto de otra búsqueda.
- **Borrar**: la carpeta se puede borrar en cualquier momento, solo cuesta bajarlo de nuevo.
  Ocupa unos 6 MB por entrada de índices a 1200 px.
- **Medido**: una corrida de cambio con índices pasó de **108 s** (caché fría) a **18 s**
  (tibia).

`--max-items` viene en 4. Medido sobre la misma caja: con 2 ítems la cobertura fue 97,4% y
con 8, 97,8%, por 65% más de tiempo. Más ítems agregan poco salvo en zonas muy nubladas.

## Requisitos

| Cosa | Para qué | Obligatorio |
| --- | --- | --- |
| **Python 3.11+** (probado en 3.13) | backend y pipeline | sí |
| **Node.js 20+** | recompilar el frontend | no, el build ya está incluido |
| **Docker Desktop** | correr en contenedor | no |
| **Cuenta Earthdata** (gratis) | bajar los `.h5` de ASF | no, solo para descargar |

Windows es el entorno soportado por los scripts `.bat`/`.ps1`. En Linux/macOS el backend
corre igual, pero el arranque es a mano (ver *Modo manual*).

## Arranque rápido

1. Cloná el repo.
2. Doble clic en **`ARRANCAR.bat`**.

Eso es todo. El script verifica Python, crea los dos entornos virtuales, instala las
dependencias, te pregunta dónde guardar los datos, levanta el servidor y abre el navegador.

La primera vez tarda unos minutos (instala `rasterio`, `h5py`, `matplotlib`…). Las
siguientes arranca en segundos.

Para apagarla: **`APAGAR.bat`**.

### Qué te va a preguntar

- **Carpeta de datos**: dónde se guardan los `.h5`. Cada escena ronda los 2 GB. Elegí un
  disco local, fuera de OneDrive.
- **Credenciales Earthdata**: usuario y contraseña de <https://urs.earthdata.nasa.gov/>.
  Son gratis y solo hacen falta para descargar productos. Podés saltearlas: la búsqueda y
  el browse funcionan sin cuenta.
- **FIRMS MAP_KEY**: opcional, solo para el producto de incendio.

Todo queda en dos archivos `.env` locales, que **no** se versionan.

## Modo Docker

```powershell
ARRANCAR.bat docker
```

O a mano:

```powershell
docker compose build
docker compose up -d
```

La app escucha en `http://127.0.0.1:8010` (o el `PORT` de tu `.env`). Los `.h5` se montan
desde `NISAR_DATA` y los artefactos desde `NISAR_MEDIA`.

> La app ejecuta subprocesos y no tiene autenticación: escucha solo en loopback a propósito.
> Para exponerla a Internet hace falta un proxy con HTTPS y, si es pública, un modo demo con
> artefactos precalculados y límites de descarga.

## Modo manual (sin los `.bat`)

```powershell
.\setup.ps1
.\configurar.ps1 -Modo Local
.\run.ps1
```

En Linux/macOS, el equivalente:

```bash
python -m venv .venv && .venv/bin/pip install -r requirements-pipeline.txt
python -m venv nisar-app/.venv && nisar-app/.venv/bin/pip install -r nisar-app/requirements.txt
nisar-app/.venv/bin/python -m uvicorn nisar_backend.main:app --app-dir nisar-app --port 8010
```

## Configuración

`configurar.ps1` escribe dos archivos, y los dos están en `.gitignore`:

| Archivo | Variables |
| --- | --- |
| `.env` | `NISAR_DATA`, `NISAR_MEDIA`, `PORT` |
| `nisar-app/.env` | `EARTHDATA_USER`, `EARTHDATA_PASSWORD`, `FIRMS_MAP_KEY` |

`env.example` documenta cada variable. La plantilla se puede editar a mano; el asistente la
respeta si ya existe una carpeta elegida, para no perder el historial de trabajos.

## Desarrollo del frontend

```powershell
cd nisar-app\frontend
npm install
npm run dev          # Vite en :5174, con proxy al backend en :8010
npm run build        # recompila dist/, que SI se versiona
```

`nisar-app/frontend/dist` se versiona a propósito: así el repo funciona sin Node. Si tocás
el frontend, acordate de correr `npm run build` y commitear el `dist/`.

## Tests

```powershell
nisar-app\.venv\Scripts\python.exe -m unittest discover -s nisar-app\nisar_backend\tests -q
```

45 tests, sin red: cubren el contrato de la API, la validación de la caja, el proxy de
browse, la detección de `.h5` en disco, la timeline y el plan exacto de cada producto. Las
búsquedas reales contra ASF se comprueban a mano.

## Estructura

```text
.
├── ARRANCAR.bat          arranque en un paso (local por defecto)
├── ARRANCAR-LOCAL.bat    alias de ARRANCAR.bat sin argumentos
├── APAGAR.bat            baja el contenedor o el servidor local
├── configurar.ps1        asistente: carpetas, credenciales y puerto
├── setup.ps1             crea los dos venv e instala dependencias
├── run.ps1               levanta uvicorn con la config del .env
├── Dockerfile            imagen de la app
├── docker-compose.yml    servicio con volumenes y healthcheck
├── requirements-pipeline.txt   dependencias del pipeline (venv raiz)
├── comun/                kit NISAR, rutas, Sentinel-2, optico, FIRMS
├── descargar/            descarga de escenas desde ASF
├── prototipos/           renderizadores NISAR (GCOV, SME2, GUNW)
├── datos/                recursos auxiliares del pipeline
└── nisar-app/
    ├── nisar_backend/    FastAPI: API + cola de jobs
    ├── frontend/         React + Leaflet (src y dist)
    ├── tests/
    └── requirements.txt  dependencias del backend (venv propio)
```

La app usa **dos entornos separados** a propósito: el backend (FastAPI) y el pipeline
(rasterio, h5py, matplotlib). Si arrancás el backend con el Python equivocado vas a ver
`No module named uvicorn`.

## Datos y créditos

- **NISAR L2 GCOV, L3 SME2, L1 GUNW** (colecciones PROVISIONAL): NASA / ISRO, archivados por
  [ASF DAAC](https://search.asf.alaska.edu/). Acceso con Earthdata Login.
- **Sentinel-2 L2A**: ESA Copernicus, vía [Microsoft Planetary Computer](https://planetarycomputer.microsoft.com/).
- **FIRMS**: NASA EOSDIS, para los focos de calor del producto incendio.
- **OpenStreetMap**: mapa base del visor.

NISAR es una misión conjunta de NASA y la Indian Space Research Organisation. Este proyecto
es de participantes del NASA Space Apps Challenge: no es un producto de NASA.

### Límite de Paraguay

`datos/paraguay_gadm.json` **no se versiona**: proviene de GADM 4.1, cuya licencia permite
uso académico y no comercial pero no su redistribución. El preset de Paraguay responde 404
si el archivo no está.

Para habilitarlo, bajá un límite administrativo de Paraguay con licencia compatible y
guardalo con ese nombre:

- [Natural Earth](https://www.naturalearthdata.com/) — dominio público, sin restricciones.
- [geoBoundaries](https://www.geoboundaries.org/) — CC-BY 4.0.

El resto de la app funciona sin ese archivo.

## Problemas comunes

- **El puerto 8010 está ocupado**: `configurar.ps1` muestra el PID y pide otro. Si lo ocupa
  el propio contenedor, lo recrea solo.
- **`FileNotFoundError` en la carpeta de datos**: la unidad o la ruta no existe (por ejemplo,
  un disco externo desconectado). Volvé a correr `configurar.ps1` y elegí una carpeta local.
- **Docker no responde**: `ARRANCAR.bat docker` espera hasta 3 minutos. Si no arranca, abrí
  Docker Desktop hasta que diga "Engine running" y reintentá.
- **Datos y artefactos en la misma carpeta**: funciona, pero conviene separarlos
  (`.../nisar-data` y `.../nisar-media`, que es el default).

## Licencia

MIT. Ver [LICENSE](LICENSE).
