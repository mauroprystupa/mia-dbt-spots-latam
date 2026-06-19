WITH source AS (
    SELECT * FROM {{ source('mia_raw', 'mexico') }}
),

-- Filtrar a los 2 archivos más recientes.
-- Mismo patrón obligatorio que stg_brasil.
ultimos_dos AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY archivo_fuente DESC) AS _rank_archivo
    FROM source
),

-- Dedup intra-archivo por clave natural de México.
-- hora_gmt se usa como string opaco en la clave — no se normaliza a UTC en esta etapa.
deduplicado AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                archivo_fuente,
                hora_gmt,
                canal,
                marca,
                version,
                duracion_programada
            ORDER BY (SELECT NULL)
        ) AS _row_num
    FROM ultimos_dos
    WHERE _rank_archivo <= 2
),

-- Extraer hora local del campo hora_gmt.
-- Formato fuente: '2024-08-24 07:27:08 -06:00'
-- El proveedor entrega el campo en hora local de México con el offset como decorador.
-- Los primeros 19 caracteres son el datetime local; el offset no se procesa.
parseado AS (
    SELECT
        *,
        PARSE_DATETIME('%Y-%m-%d %H:%M:%S', SUBSTR(hora_gmt, 1, 19)) AS _datetime_local
    FROM deduplicado
    WHERE _row_num = 1
)

SELECT
    'MEXICO'                                        AS mercado,
    archivo_fuente,
    updated_at,
    DATE(_datetime_local)                           AS fecha_emision,
    TIME(_datetime_local)                           AS hora_emision,
    medio                                           AS medio_raw,
    canal                                           AS canal_raw,
    estacion_canal,
    grupo_estacion,
    grupo_comercial,
    localidad,
    cobertura,
    spot_tipo,
    marca                                           AS marca_raw,
    producto,
    version,
    sector,
    sub_sector                                      AS subsector,
    categoria,
    duracion_programada                             AS duracion_programada_segundos,
    seg_truncados                                   AS segundos_truncados,
    duracion_programada - COALESCE(seg_truncados, 0) AS duracion_segundos,
    CAST(NULL AS FLOAT64)                           AS costo_usd_real
FROM parseado
