# syntax=docker/dockerfile:1

FROM python:3.13-slim

# uv instala desde los requirements exportados de uv.lock: mismas versiones que
# en local y sin recalcular el arbol de dependencias. Version fijada a proposito
# para que el build no cambie solo.
COPY --from=ghcr.io/astral-sh/uv:0.13.8 /uv /bin/uv

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CLIMATE3D_CONTENEDOR=1 \
    CLIMATE3D_DATOS=/data \
    CLIMATE3D_NISAR=/data/nisar \
    CLIMATE3D_PYTHON=/usr/local/bin/python \
    NISAR_S2_CACHE=/app/nisar-app/var/media/cache/s2 \
    UV_PYTHON_DOWNLOADS=0

# curl: healthcheck. libgomp1: wheel de rasterio/numpy.
# libexpat1: el wheel de rasterio lo exige en runtime; sin el, el import falla
# con "libexpat.so.1: cannot open shared object file" y sentinel2.py reporta
# "faltan rasterio/pystac-client/planetary-computer".
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      libexpat1 \
      libgomp1 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencias primero: cambiar el codigo no reinstala todo.
# `--system` instala en el Python de la imagen, que es el que usa la app
# (CLIMATE3D_PYTHON). Los requirements son un export fijado de uv.lock.
COPY requirements-pipeline.txt ./
COPY nisar-app/requirements.txt ./backend-requirements.txt
RUN uv pip install --system --no-cache \
      -r requirements-pipeline.txt -r backend-requirements.txt

# Pipeline compartido + app + frontend ya compilado.
# prototipos/ incluye poster_indices.py (panel NDVI/NDBI/NDWI); matplotlib ya
# viene en requirements-pipeline.txt.
COPY comun ./comun
COPY descargar ./descargar
COPY prototipos ./prototipos
COPY datos ./datos
COPY nisar-app/nisar_backend ./nisar-app/nisar_backend
COPY nisar-app/frontend/dist ./nisar-app/frontend/dist

# La cache de Sentinel-2 se crea vacia y con dueno correcto antes de arrancar:
# si la creara la app en runtime, el volumen montado podria no ser escribible.
RUN useradd --create-home --uid 1000 --shell /bin/bash appuser \
  && mkdir -p /app/nisar-app/var/media/cache/s2 /app/nisar-app/var/nisar/cache \
  && chown -R appuser:appuser /app/nisar-app/var

USER appuser

EXPOSE 8010

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8010/api/health > /dev/null || exit 1

CMD ["python", "-m", "uvicorn", "nisar_backend.main:app", \
     "--app-dir", "nisar-app", "--host", "0.0.0.0", "--port", "8010"]
