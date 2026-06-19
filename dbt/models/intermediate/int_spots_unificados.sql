WITH brasil AS (
    SELECT
        mercado,
        archivo_fuente,
        updated_at,
        fecha_emision,
        hora_emision,
        medio_raw,
        canal_raw,
        localidad,
        spot_tipo,
        marca_raw,
        producto,
        version,
        sector,
        subsector,
        duracion_segundos,
        costo_usd_real,
        -- Columnas exclusivas de Brasil
        red,
        operador,
        programa,
        agencia,
        es_primera_emision,
        -- Columnas exclusivas de México (NULL para Brasil)
        CAST(NULL AS STRING)  AS estacion_canal,
        CAST(NULL AS STRING)  AS grupo_estacion,
        CAST(NULL AS STRING)  AS grupo_comercial,
        CAST(NULL AS STRING)  AS cobertura,
        CAST(NULL AS STRING)  AS categoria,
        CAST(NULL AS INT64)   AS duracion_programada_segundos,
        CAST(NULL AS INT64)   AS segundos_truncados
    FROM {{ ref('stg_brasil') }}
),

mexico AS (
    SELECT
        mercado,
        archivo_fuente,
        updated_at,
        fecha_emision,
        hora_emision,
        medio_raw,
        canal_raw,
        localidad,
        spot_tipo,
        marca_raw,
        producto,
        version,
        sector,
        subsector,
        duracion_segundos,
        costo_usd_real,
        -- Columnas exclusivas de Brasil (NULL para México)
        CAST(NULL AS STRING)  AS red,
        CAST(NULL AS STRING)  AS operador,
        CAST(NULL AS STRING)  AS programa,
        CAST(NULL AS STRING)  AS agencia,
        CAST(NULL AS BOOLEAN) AS es_primera_emision,
        -- Columnas exclusivas de México
        estacion_canal,
        grupo_estacion,
        grupo_comercial,
        cobertura,
        categoria,
        duracion_programada_segundos,
        segundos_truncados
    FROM {{ ref('stg_mexico') }}
),

unificado AS (
    SELECT * FROM brasil
    UNION ALL
    SELECT * FROM mexico
)

SELECT
    mercado,
    archivo_fuente,
    updated_at,
    fecha_emision,
    hora_emision,
    medio_raw,

    CASE
        -- Brasil: TC = TV Cable, TV = TV Abierta
        WHEN mercado = 'BRASIL' AND medio_raw = 'TC'  THEN 'TELEVISION_CABLE'
        WHEN mercado = 'BRASIL' AND medio_raw = 'TV'  THEN 'TELEVISION_ABIERTA'

        -- Brasil RD: FM/AM según nombre del canal.
        -- STRPOS en lugar de REGEXP porque RE2 de BigQuery no soporta \b (word boundary).
        -- Caso explícito para RADIO ITATIAIA BH: nombre sin marcador FM/AM, es estación AM (610 AM BH).
        WHEN mercado = 'BRASIL' AND medio_raw = 'RD'
             AND canal_raw = 'RADIO ITATIAIA BH'       THEN 'RADIO_AM'
        WHEN mercado = 'BRASIL' AND medio_raw = 'RD'
             AND STRPOS(UPPER(canal_raw), ' AM') > 0   THEN 'RADIO_AM'
        WHEN mercado = 'BRASIL' AND medio_raw = 'RD'   THEN 'RADIO_FM'

        -- México: tres categorías de TV colapsan en dos del enum
        WHEN mercado = 'MEXICO'
             AND medio_raw = 'Televisión de Paga'          THEN 'TELEVISION_CABLE'
        WHEN mercado = 'MEXICO'
             AND medio_raw IN (
                 'Televisión Abierta Nacional',
                 'Televisión Abierta Local'
             )                                             THEN 'TELEVISION_ABIERTA'
        WHEN mercado = 'MEXICO' AND medio_raw = 'Radio - FM' THEN 'RADIO_FM'
        WHEN mercado = 'MEXICO' AND medio_raw = 'Radio - AM' THEN 'RADIO_AM'

        -- NULL intencionalmente ausente: el test not_null detecta valores de medio_raw no mapeados
    END                                                    AS medio,

    canal_raw,
    localidad,
    spot_tipo,
    marca_raw,
    producto,
    version,
    sector,
    subsector,
    duracion_segundos,
    costo_usd_real,

    -- Columnas exclusivas de Brasil (NULL para México)
    red,
    operador,
    programa,
    agencia,
    es_primera_emision,

    -- Columnas exclusivas de México (NULL para Brasil)
    -- duracion_programada_segundos se preserva: forma parte de la clave natural de México en int_spots_validados
    estacion_canal,
    grupo_estacion,
    grupo_comercial,
    cobertura,
    categoria,
    duracion_programada_segundos,
    segundos_truncados

FROM unificado
