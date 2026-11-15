# Comparador de barrido antes/después

Rama: `feat/comparador-barrido`. Entrega: PR contra `main`, `dist/` recompilado.
Tests: `unittest` del backend (45, sin red) + `npm run build` (tsc + Vite).

## Specs

- **S1** — En el panel de trabajos, debajo de las imágenes de "Resultados", aparece un botón
  cuando la corrida dejó las dos capas del par: "Comparar antes/después".
- **S2** — El botón abre una ventana flotante (modal accesible, cierra con Escape, con el
  botón Cerrar y con un clic fuera) con las dos imágenes superpuestas y una línea vertical
  que se arrastra con el mouse: a la izquierda el antes, a la derecha el después.
- **S3** — El barrido responde a arrastre de puntero (mouse y touch), a flechas del teclado
  (←/→, con Shift salta más) y a Home/End; arranca al 50 % y el lienzo se adapta al
  aspecto real de la imagen.
- **S4** — Las etiquetas "Antes · <fecha>" y "Después · <fecha>" salen del JSON de la corrida
  (`fecha_antes`, `fecha_despues`); si no están, dicen "Antes" y "Después".
- **S5** — El pipeline de cambio (`prototipos/nisar_cambio.py`, `--modo comparar`) deja
  además `*_antes.png` y `*_despues.png`: misma grilla, misma escala de grises que el
  compuesto, con la máscara del cambio sobre el después. Sin pie ni barra de escala.
- **S6** — El contrato entre pipeline y visor es el sufijo del nombre
  (`_antes.png`, `_despues.png`); el frontend no corta el compuesto.
- **S7** — `nisar-app/frontend/dist` se recompila y se versiona; el README documenta el botón.

## Tasks

- [x] T1 · pipeline: `_guardar_panel` + dos capas en modo comparar + meta `paneles` · inline · S5-S6
- [x] T2 · frontend: `ComparadorBarrido.tsx`, CSS y botón en `JobsPanel` · inline · S1-S4, S6
- [x] T3 · build de `dist/`, tests del backend, smoke del helper, README · inline · S7

## Log

- **L1** — Pedido del usuario, verbatim:
  "Nueva funcionalidad. Quiero que crees una nueva rama para trabajar en lo siguiente:
  Necesito tener un visualizador de imagen, es decir, que tenga un boton abajo del resultado
  que cuando yo haga click este abra una ventana flotante para visualizar la imagen, aqui
  viene lo novedoso, esta ventana tiene que tener funcion de barrido, es decir, no quiero ver
  dos mapas al lado, si no que yo con el mouse pueda arrastrar y ver el antes y despues, casi
  igual que implementamos en la comparacion del sitio https://gillopy.github.io/nisar-canopy-site/"
- **L2** — Evidencia: el compuesto del producto de cambio (`nisar_cambio_comparar_2400.png`)
  ya trae antes | después + máscara y un pie con leyenda, pero no hay capas sueltas, así que
  sin un par de imágenes el barrido no se puede hacer sin recortar el compuesto. El sitio de
  referencia usa dos imágenes separadas con una línea arrastrable.
- **L3** — Riesgo de la solución: la corrida de cambio pasa de 1 a 3 PNG (compuesto + dos
  capas). Se acepta porque las capas son el insumo del comparador y quedan como artefactos
  reproducibles; se limitan a la mitad del ancho pedido para no duplicar peso.
- **L4** — Evidencia de cierre: `_guardar_panel` probado con un array sintético (recorte a
  80x45 y sin agrandar a 4096); `py_compile` del script; `npm run build` (tsc + Vite) OK;
  45 tests del backend OK; el modal y el bloque del botón se verificaron renderizando el
  CSS compilado en Edge headless a 1280x900 y 410 px de columna. No se pudo correr un job
  real de cambio (necesita Earthdata + `.h5`): el camino completo pipeline → artefactos →
  visor queda pendiente de una corrida con datos.
- **L5** — Verificación independiente (`gentle-ai-verify`), sin bloqueantes. Corregido: el
  respaldo de la etiqueta duplicaba el prefijo ("Antes · Antes") y el arrastre podía quedar
  colgado si se perdía el pointer capture (`onLostPointerCapture`). Conocido y no cambiado:
  `jobs.py::_publicar` publica sólo el PNG más nuevo cuando ningún archivo quedó fresco; hoy
  no se dispara en `cambio` porque la receta siempre agrega el render y el script reescribe
  los tres PNG, pero si algún día se cachea el render el par no se publicaría.
