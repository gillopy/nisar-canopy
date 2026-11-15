# Índices ópticos para bosque (NBR/dNBR)

Rama: `feat/indices-bosque` (local). Entrega: commit local; el push queda a decisión del autor.
Tests: `unittest` del backend (45, sin red); el pipeline óptico se valida con datos reales de
Sentinel-2 sobre el caso Chaco.

## Specs

- **S1** — El panel Sentinel-2 del cambio de cobertura suma una fila **NBR** (antes, después y
  delta) junto a NDVI, NDBI y NDWI.
- **S2** — NBR usa **SWIR2 (B12)**: se agrega esa banda al conjunto del panel
  (`BANDAS_INDICES`). Cambia la clave de caché de Sentinel-2, así que la primera corrida se
  recalcula; los otros productos (fusión, serie, incendio) siguen con B04/B08/SCL.
- **S3** — La columna de delta usa escala propia por índice; dNBR va a ±0,6 porque los cortes
  de severidad de referencia van de 0,27 a 0,66.
- **S4** — README actualizado: la fila nueva y por qué SWIR2, aclarando que la captura es del
  panel de tres índices.
- **S5** — Validación con datos reales: compuesto de las dos fechas del caso Chaco, panel
  renderizado y estadísticas de NBR/dNBR.

## Tasks

- [x] T1 · `optico.nbr()` + `_calcular_indices` + `BANDAS_INDICES` con B12 · inline · S1-S2
- [x] T2 · fila NBR y escala de delta por índice en `poster_indices.py` · inline · S1, S3
- [x] T3 · README + validación real con Sentinel-2 · inline · S4-S5

## Log

- **L1** — Pedido, verbatim: "Quiero saber si podemos crear o usar otros filtros mas adecuados
  para la comparacion sentinel, por el momento usamos NVDI NDBI y NDWI, quiero saber si hay algo
  que te pueda servir de este repositorio https://github.com/sentinel-hub/custom-scripts/tree/main/sentinel-2
  yo se que hay otros filtros para agricultura, en este caso quiero adaptar algo para los bosques,
  analiza y dime si hay algo adecuado. Todavia no escribas codigo."
- **L2** — Autorización: "Haz lo recomendable, quiero probarlo, luego te digo si avanzamos o no."
- **L3** — Análisis: el repo de sentinel-hub tiene 856 scripts; los de bosque no son portables
  (`forest_disturbance_classification` es un LightGBM entrenado en Europa; `forest_cut_temporal_detection`
  necesita comparación interanual; `pseudo_forest_canopy_density` necesita calibración local).
  Dato duro del código propio: `NDMI = (B08-B11)/(B08+B11)` es exactamente `-NDBI` con nuestras
  bandas, y MSI es monótono sobre el mismo cociente; NDWI ≈ `-NDVI` sobre vegetación. La única
  familia espectral que falta es SWIR2 (B12), donde vive NBR/dNBR. Se descartó sumar BSI (B02)
  en esta tanda para no ampliar el alcance antes de la prueba.
- **L4** — Validación real (caja del historial local, 2026-06-28 → 2026-10-26, 4 ítems por fecha,
  sin nubes): NBR medio 0,114 → 0,095 (p10 -0,004 → -0,008, p90 0,219 → 0,179); dNBR medio
  **-0,019**, p10 -0,093, p90 +0,044; 1,44 % de píxeles con dNBR > 0,1 y 0 % > 0,27.
  Correlación dNDVI vs dNBR **+0,94**: en esta caja el cambio es chico y ambos índices ordenan
  parecido, así que dNBR aporta escala estándar y robustez de fondo, no una señal independiente.
  El panel de 4 filas se renderizó y se revisó a ojo.
- **L5** — Queda a decisión del autor si avanzamos con BSI/B02, con dNBR como segunda
  confirmación óptica del cambio, o si NBR se queda sólo como capa de visualización.
- **L6** — Verificación independiente: S1-S4 cumplen; sin bloqueantes. Hallazgo no bloqueante
  corregido en documentación: las columnas de delta van **después − antes**, así que el valor
  mostrado es el **negativo** del dNBR estándar (USGS define antes − después); el signo no
  cambia la escala ni el render, pero la ficha y el README ahora lo dicen explícito. No se
  agregó test automático: el venv del backend no tiene numpy a propósito (el backend no carga
  dependencias del pipeline) y el repo no tiene runner para `comun/`, así que la evidencia es
  la corrida real de L4.
