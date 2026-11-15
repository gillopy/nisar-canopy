# Materiales de terceros

Este archivo cumple dos cosas: deja identificadas las licencias de todo lo que el
repositorio **redistribuye**, y separa lo que solo se **instala** al armar los entornos.

Los Términos y Condiciones del NASA Space Apps Challenge piden que todo material de terceros
sea libre y públicamente disponible o tenga licencia OSI, que las licencias queden
identificadas en la documentación, y que se cite cada fuente.

## Lo que este repositorio redistribuye

Estos archivos viajan dentro del repo (y dentro de la imagen Docker), así que sus licencias
se incluyen completas en [`LICENSES/`](LICENSES/).

| Material | Dónde | Licencia | Texto |
| --- | --- | --- | --- |
| Fuentes **Archivo** | `nisar-app/frontend/src/fonts/archivo-latin.woff2` y su copia en `dist/assets/` | SIL Open Font License 1.1 | [OFL-Archivo.txt](LICENSES/OFL-Archivo.txt) |
| Fuentes **Archivo Narrow** | `nisar-app/frontend/src/fonts/archivo-narrow-latin.woff2` y su copia en `dist/assets/` | SIL Open Font License 1.1 | [OFL-Archivo-Narrow.txt](LICENSES/OFL-Archivo-Narrow.txt) |
| **Leaflet** (compilado en el bundle) | `nisar-app/frontend/dist/assets/index-*.js` y `index-*.css` | BSD 2-Clause | [BSD-2-Clause-Leaflet.txt](LICENSES/BSD-2-Clause-Leaflet.txt) |
| **React** y **React DOM** (compilados en el bundle) | `nisar-app/frontend/dist/assets/index-*.js` | MIT | [MIT-React.txt](LICENSES/MIT-React.txt) |

## Lo que se instala, no se redistribuye

El resto son dependencias que `uv sync` (o `pip`) instalan en la máquina de quien corre el
proyecto. No hay código de ellas en el repositorio: se resuelven desde PyPI y npm con las
versiones exactas que fija `uv.lock`, y cada paquete trae su propia licencia.

Componentes principales:

| Componente | Licencia |
| --- | --- |
| numpy, h5py, rasterio, psutil, uvicorn, tifffile | BSD |
| fastapi, pyproj, Pillow, attrs | MIT / Apache-2.0 |
| matplotlib | Python Software Foundation License |
| pystac-client, planetary-computer, pystac | Apache-2.0 |
| requests | Apache-2.0 |
| certifi | MPL-2.0 |
| Vite, TypeScript | MIT / Apache-2.0 (solo build) |
| uv | Apache-2.0 / MIT (solo build) |

Si necesitás la licencia exacta de un paquete puntual: `uv tree` en el proyecto y la ficha
del paquete en PyPI.

## Datos: no se redistribuyen

El repositorio **no incluye** imágenes satelitales. Todo se descarga en tiempo de ejecución
con la cuenta de cada usuario.

| Fuente | Uso | Condiciones |
| --- | --- | --- |
| **NISAR** L2 GCOV, L3 SME2, L1 GUNW (NASA / ISRO, ASF DAAC) | producto principal | datos abiertos de NASA, acceso con Earthdata Login |
| **Sentinel-2 L2A** (ESA Copernicus, vía Microsoft Planetary Computer) | verificación óptica e índices | datos abiertos Copernicus |
| **NASA FIRMS** | focos de calor del producto incendio | datos abiertos, requiere MAP_KEY gratuito |
| **OpenStreetMap** | mapa base del visor | © OpenStreetMap contributors, ODbL; la atribución se muestra en el mapa |

### Lo que quedó fuera a propósito

`datos/paraguay_gadm.json` **no se versiona ni entra en la imagen**: proviene de GADM 4.1,
cuya licencia permite uso académico y no comercial pero **no** su redistribución. El README
explica cómo reemplazarlo por un límite con licencia compatible (Natural Earth, dominio
público; geoBoundaries, CC-BY 4.0).

## Marcas

NASA, NISAR y los nombres de misiones se usan solo para referirse a los datos y a la
iniciativa. Este proyecto **no incluye logos, insignias ni identificadores gráficos** de NASA
ni de ISRO, y no está avalado por ninguna de las dos agencias.
