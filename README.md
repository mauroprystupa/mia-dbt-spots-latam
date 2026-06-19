# mia-data

Pipeline dbt + BigQuery que unifica datos de spots publicitarios de TV y Radio de **Brasil** y **México** para el producto **MIA**.

Procesa ~27k spots diarios desde tablas consolidadas en `mia_raw`, aplica lógica de negocio estandarizada en capas intermedias y expone una tabla de hechos en `mia_marts` lista para dashboards y análisis.

---

## Stack

| Componente | Tecnología |
|-----------|-----------|
| Transformaciones | dbt 1.11 (Standard SQL BigQuery) |
| Base de datos | Google BigQuery |
| GCP Project | `web-nineteen` · región `us-central1` |

---

## Arquitectura

```
mia_raw           →  tablas fuente por mercado (brasil, mexico)
      ↓
mia_staging       →  vistas: limpieza, parseo, dedup intra-archivo
      ↓
mia_intermediate  →  vistas: validación, segmentos, costos, normalización
      ↓
mia_marts         →  tablas: fct_spots + dimensiones
```

| Dataset | Materialización | Responsabilidad |
|---------|----------------|----------------|
| `mia_raw` | Tabla | Fuente consolidada con columna `archivo_fuente` para lineage |
| `mia_staging` | Vista | Parseo, casteos y dedup intra-archivo por mercado |
| `mia_intermediate` | Vista | Unificación, validación de falsos positivos, segmentos, costos, referencias |
| `mia_marts` | Tabla (particionada + clustered) | `fct_spots`, `dim_canales`, `dim_marcas`, `dim_segmentos` |

---

## Modelos

### Staging

| Modelo | Fuente | Notas |
|--------|--------|-------|
| `stg_brasil` | `mia_raw.brasil` | Parseo `DD/MM/YYYY`; `ValorDolar = 0` → NULL |
| `stg_mexico` | `mia_raw.mexico` | Hora local extraída de `Hora GMT`; `costo_usd_real = NULL` |

Ambos aplican `DENSE_RANK() OVER (ORDER BY archivo_fuente DESC) <= 2` como guardia explícita contra la acumulación de archivos históricos.

### Intermediate _(en desarrollo)_

| Modelo | Responsabilidad |
|--------|----------------|
| `int_spots_unificados` | UNION ALL ambos mercados · normalización de `medio` al enum canónico |
| `int_spots_validados` | Dedup cross-archivo · flag `is_valid` por lógica de ventana deslizante |
| `int_segmentos_horarios` | `segmento_horario` por hora local (Primetime cruza medianoche: 18:00–01:59) |
| `int_costos_estimados` | Promedio por `mercado + medio + segmento` cuando `costo_usd_real IS NULL` |
| `int_canales_normalizados` | JOIN contra `mia_ref.ref_canales` → `canal_normalizado`, `grupo_canal` |
| `int_marcas_normalizadas` | JOIN contra `mia_ref.ref_marcas` → `marca_comercial` |

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

```yaml
mia_data:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: web-nineteen
      dataset: mia_staging
      location: us-central1
      threads: 4
```

Verificar:

```bash
dbt debug --project-dir dbt
```

---

## Correr el pipeline

```bash
# Staging (estado actual)
dbt run  --project-dir dbt --select staging
dbt test --project-dir dbt --select staging

# Pipeline completo (cuando intermediate y marts estén implementados)
dbt run  --project-dir dbt
dbt test --project-dir dbt
```

---

## Testing

Los modelos de staging incluyen:

- `not_null` en columnas críticas (`fecha_emision`, `hora_emision`, `canal_raw`, `marca_raw`, `duracion_segundos`)
- `accepted_values` para `mercado` y `archivo_fuente`
- `max_distinct_values: 2` en `archivo_fuente` — test custom que falla explícitamente si se cargan más de dos archivos, evitando corrupción silenciosa de la lógica de validación

---

## Tablas de referencia

`mia_ref.ref_canales` y `mia_ref.ref_marcas` se cargan desde Google Sheets directamente a BigQuery, fuera del scope de este pipeline dbt.
