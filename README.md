# mia-data

Pipeline dbt + BigQuery que unifica datos de spots publicitarios de TV y Radio de **Brasil** y **México** para el producto **MIA**.

Procesa spots desde tablas consolidadas en `mia_raw`, aplica lógica de negocio estandarizada en capas intermedias y expone una tabla de consumo en `mia_marts` lista para dashboards y análisis.

---

## Informe Final

Pipeline dbt sobre BigQuery que unifica spots de TV y Radio de Brasil y México en una única tabla de consumo (`spots_latam`). El proceso cubre limpieza y parseo por mercado en staging, y aplica en capas intermediate: unificación, detección de falsos positivos, segmentos horarios, estimación de costos y normalización de canales y marcas vía tablas de referencia externas. Los principales desafíos fueron: la detección de falsos positivos entre archivos de distintas fechas de auditoría (resuelto con lógica de ventana deslizante y flag `is_valid`), el parseo de zona horaria en México (resuelto extrayendo los primeros 19 caracteres del campo `Hora GMT`), y la ausencia de costos reales para México (resuelto con estimación por promedio de Brasil — supuesto documentado explícitamente). La tabla final incluye todos los registros con el flag de validez para que el consumidor decida el filtro. Como análisis adicional, se construyó un dashboard interactivo standalone que evidencia la alta concentración del mercado en apuestas deportivas y streaming, y la dominancia del grupo ESPN en el inventario disponible.

Muestra de la tabla final: [`dashboard/spot_latam.csv`](dashboard/spot_latam.csv)

---

## Contenido del repositorio

- [`dbt/`](dbt/) — proyecto dbt completo: modelos de staging, intermediate y marts, macros, tests y configuración de conexión a BigQuery.
- [`dashboard/`](dashboard/) — dashboard standalone HTML que consume `spots_latam`. Incluye [instrucciones de uso](dashboard/README.md) y un [análisis del período](dashboard/ANALISIS.md).
- [`.env.example`](.env.example) — variables de entorno requeridas para conectarse a GCP.

---

## Stack

| Componente       | Tecnología                      |
| ---------------- | -------------------------------- |
| Transformaciones | dbt 1.11 (Standard SQL BigQuery) |
| Base de datos    | Google BigQuery                  |
| GCP Project      | xxx· región `us-central1`    |

---

## Arquitectura

```
mia_raw           →  tablas fuente por mercado (brasil, mexico)
      ↓
mia_staging       →  tablas: limpieza, parseo, dedup intra-archivo
      ↓
mia_intermediate  →  tablas: validación, segmentos, costos, normalización
      ↓
mia_marts         →  tabla: spots_latam (tabla ancha, consumo directo)
```

| Dataset              | Materialización                 | Responsabilidad                                                               |
| -------------------- | -------------------------------- | ----------------------------------------------------------------------------- |
| `mia_raw`          | Tabla                            | Fuente consolidada con columna `archivo_fuente` para lineage                |
| `mia_staging`      | Tabla                            | Parseo, casteos y dedup intra-archivo por mercado                             |
| `mia_intermediate` | Tabla                            | Unificación, validación de falsos positivos, segmentos, costos, referencias |
| `mia_marts`        | Tabla (particionada + clustered) | `spots_latam` — tabla ancha desnormalizada, consumo directo                |

---

## Modelos

### Staging

| Modelo         | Fuente             | Notas                                                           |
| -------------- | ------------------ | --------------------------------------------------------------- |
| `stg_brasil` | `mia_raw.brasil` | Parseo `DD/MM/YYYY`; `ValorDolar = 0` → NULL               |
| `stg_mexico` | `mia_raw.mexico` | Hora local extraída de `Hora GMT`; `costo_usd_real = NULL` |

Ambos aplican `DENSE_RANK() OVER (ORDER BY archivo_fuente DESC) <= 2` como guardia explícita contra la acumulación de archivos históricos.

### Intermediate

| Modelo                       | Responsabilidad                                                                |
| ---------------------------- | ------------------------------------------------------------------------------ |
| `int_spots_unificados`     | UNION ALL ambos mercados · normalización de `medio` al enum canónico      |
| `int_spots_validados`      | Dedup cross-archivo · flag `is_valid` por lógica de ventana deslizante     |
| `int_segmentos_horarios`   | `segmento_horario` por hora local (Primetime cruza medianoche: 18:00–01:59) |
| `int_costos_estimados`     | Promedio por `mercado + medio + segmento` cuando `costo_usd_real IS NULL`  |
| `int_canales_normalizados` | JOIN contra `mia_ref.ref_canales` → `canal_normalizado`, `grupo_canal`  |
| `int_marcas_normalizadas`  | JOIN contra `mia_ref.ref_marcas` → `marca_comercial`                      |

El orden de ejecución lo determina dbt automáticamente a partir del DAG que construye leyendo los `{{ ref() }}` de cada modelo:

```text
stg_brasil ──┐
             ├──→ int_spots_unificados
stg_mexico ──┘            │
                          ↓
                 int_spots_validados
                          │
                          ↓
                 int_segmentos_horarios
                          │
                          ↓
                 int_costos_estimados
                          │
          ref_canales ────┤
                          ↓
                 int_canales_normalizados
                          │
           ref_marcas ────┤
                          ↓
                 int_marcas_normalizadas
                          │
                          ↓
                      spots_latam
```

### Marts

**`spots_latam`** — tabla ancha desnormalizada. Una fila por spot emitido en Brasil o México, incluyendo falsos positivos identificados con `is_valid = FALSE`. Todas las columnas analíticas resueltas inline. Particionada por `fecha_emision`, clustered por `mercado`, `medio`, `segmento_horario`. Muestra del período disponible en [`dashboard/spot_latam.csv`](dashboard/spot_latam.csv).

---

## Supuestos del pipeline

### `archivo_fuente` como fecha de auditoría

`archivo_fuente` es una string en formato `YYYYMMDD` extraída del **nombre del archivo** cuando el proveedor entrega los datos (ej. `mercado_brasil_20240831.csv` → `'20240831'`). No es la fecha de emisión de los spots.

Esto implica tres supuestos que deben cumplirse para que el pipeline funcione correctamente:

1. **El proveedor nombra sus archivos con la fecha de exportación en formato `YYYYMMDD`.** Si cambia el formato del nombre (ej. `brasil_31-08-2024.csv`), el campo `archivo_fuente` ya no es comparable y el DENSE_RANK elige los archivos incorrectos.
2. **Cada archivo cubre una ventana de N días consecutivos inmediatamente anteriores a su fecha de nombre.** El archivo `20240831` contiene spots de los N días previos al 31 de agosto; el archivo `20240901` contiene spots de los N días previos al 1 de septiembre. Ambos se solapan en N-1 días, lo que permite detectar qué spots de dia1 no fueron re-auditados en dia2 (falsos positivos). Si un archivo llegara con datos de un período sin solapamiento con el archivo anterior, los spots de dia1 no tendrían matches en dia2 y serían marcados incorrectamente como `is_valid = FALSE`.
3. **El orden lexicográfico de `archivo_fuente` coincide con el orden cronológico.** Esto es verdad mientras el formato sea `YYYYMMDD` con ceros a la izquierda: `'20240901' > '20240831'` carácter a carácter. Si el formato fuera `D/M/YYYY`, el orden lexicográfico sería incorrecto y el DENSE_RANK elegiría los archivos equivocados.

### Supuesto de costo estimado para México

México no tiene datos de costo en la fuente — el campo equivalente a `ValorDolar` de Brasil no existe. El modelo `int_costos_estimados` imputa el costo de los spots mexicanos usando el promedio de Brasil por `(medio, segmento_horario)`, sin distinción de mercado.

Esto asume que **el costo de un spot de un tipo de medio y franja horaria determinada es comparable entre Brasil y México**. Es un supuesto fuerte: ambos mercados tienen tamaños, estructuras de precios y monedas distintas. El estimado de México hereda el sesgo del mercado brasileño.

Para producción, la solución correcta es obtener datos de costo reales para México o construir un factor de ajuste por mercado. Mientras eso no esté disponible, `costo_usd_estimado` para México debe interpretarse como una aproximación de orden de magnitud, no como un valor preciso.

### Decisión de arquitectura — full refresh en la capa intermediate

La capa intermediate requiere un **full refresh del ciclo de auditoría activo** (los 2 valores de `archivo_fuente` más recientes por mercado) en cada ejecución. Esto es una consecuencia directa de la lógica de `is_valid`: determinar si un spot de `dia1` es un falso positivo requiere comparar contra todo `dia2`. La comparación es inherentemente cross-registro y no puede resolverse fila a fila.

A los volúmenes del challenge esto es aceptable. A mayor escala, la optimización correcta sería resolver la comparación cross-archivo en una capa previa a staging — produciendo el flag de re-auditoría una sola vez antes de que los datos entren al pipeline — de modo que staging y en adelante puedan ser modelos incrementales puros.

### Decisión de arquitectura — pipeline de enriquecimiento en 6 modelos

La capa intermediate está implementada como una cadena de 6 modelos independientes. Esta es una decisión de arquitectura, no deuda técnica. En esta etapa de inmadurez del pipeline, se priorizó la capacidad de debuggear la lógica de negocio con tests intermedios que permitan identificar inconsistencias rápidamente y documentarlas. A medida que el pipeline cobre madurez, los modelos se irán unificando y los tests intermedios serán reemplazados por validaciones en capas más tempranas.

**Deudas asumidas conscientemente:**

- _¿Qué pasa si un analista quiere consumir `mia_intermediate`?_ Ningún analista debería hacerlo — es una capa exclusiva del pipeline. En caso de necesidad, la documentación de cada modelo indica qué columnas agrega y cuál es el modelo final completo.
- _Materializar 6 modelos implica mayor consumo de storage._ Correcto. En esta etapa el foco está en el entendimiento de las reglas de negocio, la calidad de los datos y la resolución rápida de fallos. A medida que el pipeline madure, esa deuda se sanea consolidando modelos.

---

## Setup

### Prerequisitos

- Python 3.11+
- Acceso a GCP — `gcloud auth application-default login`

### Instalación

```bash
pip install -r requirements.txt
dbt deps --project-dir dbt
```

### Conexión BigQuery

Crear `dbt/profiles.yml` (no se versiona):

mia_data:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: xxx
      dataset: mia_staging
      location: us-central1
      threads: 4

Verificar:

```bash
dbt debug --project-dir dbt
```

---

## Correr el pipeline

```bash
dbt run  --project-dir dbt
dbt test --project-dir dbt
```

---

## Testing

73 tests distribuidos en las tres capas:

- `not_null` en columnas críticas de staging, intermediate y marts
- `accepted_values` para `mercado` (`BRASIL` / `MEXICO`), `medio` y `segmento_horario`
- `max_distinct_values: 2` en `archivo_fuente` (staging) — test custom que falla explícitamente si se cargan más de dos fechas de auditoría, evitando corrupción silenciosa de la lógica de ventana deslizante
- `not_null` en `costo_usd_final` y `canal_normalizado` y `marca_comercial` — garantizan que los fallbacks de normalización nunca producen NULLs en marts

---

## Tablas de referencia

Las tablas de referencia viven en el dataset `mia_ref` y son gestionadas fuera del pipeline dbt — se cargan directamente a BigQuery sin pasar por el repositorio.

**Por qué tablas externas y no dbt seeds:**
dbt seeds están pensados para datos pequeños y estáticos que cambian muy poco — catálogos de países, códigos de moneda, configuraciones fijas. El problema es que cualquier cambio requiere un ciclo completo de deploy: editar el CSV en el repo, commit, PR, merge, y recién entonces el cambio se refleja en producción.

En un producto como MIA, donde los clientes pueden pedir que una marca cambie de nombre o que se agregue un alias de canal, ese ciclo es un problema operativo real. Las tablas en BigQuery rompen ese acoplamiento: el equipo de negocio puede editar el diccionario de marcas o los aliases de canales directamente, sin tocar el repositorio, sin pasar por un deploy, y el cambio se refleja en la próxima corrida del pipeline. Esto es especialmente relevante porque `ref_marcas` y `ref_canales` son exactamente el tipo de dato que negocio necesita controlar sin depender del ciclo de ingeniería.

---

### `mia_ref.ref_canales`

Mapea nombres de canales tal como vienen en la fuente (`canal_raw`) a un nombre canónico y un grupo de red. Cubre casos donde el mismo canal tiene grafías distintas entre mercados o entre archivos (`ESPN2` vs `ESPN 2`, `ESPN3` vs `ESPN 3`), nombres abreviados (`SPORTV` → `SporTV`), y variantes de un mismo canal (repeticiones, feeds secundarios de Televisa).

| Columna               | Tipo   | Descripción                                                                                                 |
| --------------------- | ------ | ------------------------------------------------------------------------------------------------------------ |
| `canal_raw`         | STRING | Nombre exacto del canal tal como figura en la fuente. Clave de JOIN con los modelos intermediate.            |
| `mercado`           | STRING | `BRASIL` o `MEXICO`. El mismo `canal_raw` puede existir en ambos mercados con distinta normalización. |
| `canal_normalizado` | STRING | Nombre canónico del canal. Ejemplo:`ESPN2` → `ESPN 2`, `SPORTV` → `SporTV`.                       |
| `grupo_canal`       | STRING | Red o grupo propietario. Ejemplos:`ESPN`, `SporTV`, `Televisa`, `Warner Bros. Discovery`.            |

Canales sin entrada en esta tabla usan `canal_raw` como fallback en el modelo.

**Grupos cubiertos:** ESPN, SporTV, Globo, Band, SBT, Record, RedeTV, CNN, Warner Bros. Discovery, STAR, Fox Sports, Televisa, TV Azteca, Televisa Univision, A+E Networks, Walt Disney, Sony Pictures, FX Networks, Milenio, Multimedios, Paramount, Radio Formula.

---

### `mia_ref.ref_marcas`

Mapea el nombre de marca tal como viene en la fuente al nombre comercial correcto. Cubre diferencias de capitalización entre mercados y nombres comerciales que difieren del identificador interno.

| Columna             | Tipo   | Descripción                                                                                        |
| ------------------- | ------ | --------------------------------------------------------------------------------------------------- |
| `marca_raw`       | STRING | Nombre exacto de la marca tal como figura en la fuente. Clave de JOIN con los modelos intermediate. |
| `marca_comercial` | STRING | Nombre comercial canónico de la marca.                                                             |

Marcas sin entrada en esta tabla usan `marca_raw` como fallback en el modelo.
