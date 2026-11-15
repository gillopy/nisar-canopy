"""Panel de indices espectrales Sentinel-2: NDVI, NDBI y NDWI, antes/despues.

Se dibuja sobre la grilla del recorte NISAR (las capas ya vienen alineadas), asi que
se puede superponer o comparar con el cambio de HV. Los deltas usan una escala
divergente centrada en cero; las capas usan la paleta propia de cada indice.

Uso como modulo: `dibujar_panel(antes, despues, salida, ...)`.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

import matplotlib

matplotlib.use("Agg")  # sin ventana: los scripts corren en subprocesos
import matplotlib.pyplot as plt  # noqa: E402

#: Paleta y rango fijo por indice. Rangos fijos: el mismo indice se ve igual en
#: cualquier caja y cualquier fecha, que es lo que permite comparar corridas.
ESCALAS = {
    "ndvi": ("RdYlGn", -0.2, 0.9),
    "ndbi": ("BrBG", -0.6, 0.6),
    "ndwi": ("Blues", -0.6, 0.6),
}

NOMBRES = {"ndvi": "NDVI", "ndbi": "NDBI", "ndwi": "NDWI"}


def _recortar(capa: np.ndarray, max_px: int) -> np.ndarray:
    alto, ancho = capa.shape
    paso = max(1, int(np.ceil(max(alto, ancho) / max_px)))
    return capa[::paso, ::paso]


def _dibujar(ax, capa, titulo, cmap, vmin, vmax):
    datos = np.ma.masked_invalid(capa)
    ax.imshow(datos, cmap=cmap, vmin=vmin, vmax=vmax, interpolation="nearest")
    ax.set_facecolor("#0c0c10")  # el fondo del eje, detras de los NaN
    ax.set_title(titulo, fontsize=10, color="#e6e6ee", pad=6)
    ax.set_xticks([])
    ax.set_yticks([])
    for borde in ax.spines.values():
        borde.set_color("#2a2a33")


def dibujar_panel(
    antes: dict[str, np.ndarray],
    despues: dict[str, np.ndarray],
    salida: str | Path,
    *,
    titulo: str | None = None,
    max_px: int = 900,
) -> Path:
    """Escribe un PNG 3x3: cada indice antes, despues y su delta.

    `antes` y `despues` son dicts con las claves que el llamador haya compuesto
    (ndvi, ndbi, ndwi). Las capas ausentes se saltean sin romper el panel.
    """
    claves = [c for c in ("ndvi", "ndbi", "ndwi") if c in antes and c in despues]
    if not claves:
        raise ValueError("no hay indices para dibujar")

    ruta = Path(salida)
    ruta.parent.mkdir(parents=True, exist_ok=True)

    filas = len(claves)
    figura, ejes = plt.subplots(
        filas, 3, figsize=(12.6, 4.2 * filas), facecolor="#0c0c10"
    )
    if filas == 1:
        ejes = np.array([ejes])

    for fila, clave in enumerate(claves):
        cmap, vmin, vmax = ESCALAS[clave]
        a = _recortar(antes[clave], max_px)
        d = _recortar(despues[clave], max_px)
        delta = d - a
        _dibujar(ejes[fila][0], a, f"{NOMBRES[clave]} antes", cmap, vmin, vmax)
        _dibujar(ejes[fila][1], d, f"{NOMBRES[clave]} despues", cmap, vmin, vmax)
        media = np.nanmean(delta) if np.isfinite(delta).any() else np.nan
        _dibujar(
            ejes[fila][2],
            delta,
            f"delta {NOMBRES[clave]} (medio {media:+.3f})",
            "RdBu_r",
            -0.4,
            0.4,
        )

    if titulo:
        figura.suptitle(titulo, fontsize=12, color="#e6e6ee", y=0.995)
    figura.tight_layout()
    figura.savefig(ruta, dpi=110, facecolor=figura.get_facecolor())
    plt.close(figura)
    return ruta
