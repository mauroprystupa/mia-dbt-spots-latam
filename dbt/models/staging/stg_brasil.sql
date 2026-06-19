WITH source AS (
    SELECT * FROM {{ source('mia_raw', 'brasil') }}
),

-- Filtrar a los 2 archivos más recientes.
-- DENSE_RANK garantiza que archivos históricos no contaminen la ventana de
-- dedup ni la detección de falsos positivos en int_spots_validados.
-- OBLIGATORIO: sin este filtro, un tercer archivo rompe MIN/MAX silenciosamente.
ultimos_dos AS (
    SELECT *,
        DENSE_RANK() OVER (ORDER BY archivo_fuente DESC) AS _rank_archivo
    FROM source
),

-- Dedup intra-archivo: elimina filas exactamente duplicadas dentro del mismo archivo.
-- La clave natural de Brasil es (fecha, hora, emisora, marca, version, duracion).
-- El dedup cross-archivo se resuelve en int_spots_validados.
deduplicado AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                archivo_fuente,
                fecha,
                hora,
                emisora,
                marca,
                version,
                duracion
            ORDER BY (SELECT NULL)
        ) AS _row_num
    FROM ultimos_dos
    WHERE _rank_archivo <= 2
)

SELECT
    'BRASIL'                                    AS mercado,
    archivo_fuente,
    updated_at,
    pais,
    PARSE_DATE('%d/%m/%Y', fecha)               AS fecha_emision,
    PARSE_TIME('%H:%M:%S', hora)                AS hora_emision,
    medio                                       AS medio_raw,
    emisora                                     AS canal_raw,
    red,
    operador,
    plaza                                       AS localidad,
    programa,
    evento                                      AS spot_tipo,
    marca                                       AS marca_raw,
    producto,
    version,
    sector,
    subsector,
    agencia,
    duracion                                    AS duracion_segundos,
    NULLIF(valor_dolar, 0)                      AS costo_usd_real,
    CASE
        WHEN UPPER(es_primera) = 'TRUE'  THEN TRUE
        WHEN UPPER(es_primera) = 'FALSE' THEN FALSE
        ELSE NULL
    END                                         AS es_primera_emision
FROM deduplicado
WHERE _row_num = 1
