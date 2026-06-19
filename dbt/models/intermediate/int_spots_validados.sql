WITH spots AS (
    SELECT * FROM {{ ref('int_spots_unificados') }}
),

-- Derivar dia1 y dia2 dinámicamente por mercado — sin hardcodear fechas
archivo_range AS (
    SELECT
        mercado,
        MIN(archivo_fuente) AS archivo_dia1,
        MAX(archivo_fuente) AS archivo_dia2
    FROM spots
    GROUP BY mercado
),

-- MIN fecha de dia1 por mercado.
-- Spots en esa fecha cayeron de la ventana deslizante → nunca reauditados → is_valid = TRUE
min_fecha_dia1 AS (
    SELECT
        s.mercado,
        MIN(s.fecha_emision) AS min_fecha_dia1
    FROM spots s
    JOIN archivo_range ar USING (mercado)
    WHERE s.archivo_fuente = ar.archivo_dia1
    GROUP BY s.mercado
),

con_flags AS (
    SELECT
        s.*,
        ar.archivo_dia1,
        ar.archivo_dia2,
        mf.min_fecha_dia1,

        -- ¿Esta clave natural tiene al menos un registro en dia2?
        -- Necesario para clasificar registros de dia1 que NO fueron reauditados (is_valid = FALSE)
        MAX(CASE WHEN s.archivo_fuente = ar.archivo_dia2 THEN 1 ELSE 0 END)
            OVER (
                PARTITION BY
                    s.mercado,
                    s.fecha_emision,
                    s.hora_emision,
                    s.canal_raw,
                    s.marca_raw,
                    COALESCE(s.version, ''),
                    COALESCE(s.duracion_programada_segundos, s.duracion_segundos)
            ) AS en_dia2,

        -- Dedup cross-archivo: dia2 gana.
        -- Dentro del mismo archivo, el orden es arbitrario (ya deduplicado en staging).
        ROW_NUMBER() OVER (
            PARTITION BY
                s.mercado,
                s.fecha_emision,
                s.hora_emision,
                s.canal_raw,
                s.marca_raw,
                COALESCE(s.version, ''),
                COALESCE(s.duracion_programada_segundos, s.duracion_segundos)
            ORDER BY
                CASE WHEN s.archivo_fuente = ar.archivo_dia2 THEN 1 ELSE 2 END
        ) AS rn

    FROM spots s
    JOIN archivo_range ar USING (mercado)
    JOIN min_fecha_dia1 mf USING (mercado)
)

SELECT
    mercado,
    archivo_fuente,
    updated_at,
    fecha_emision,
    hora_emision,
    medio_raw,
    medio,
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
    red,
    operador,
    programa,
    agencia,
    es_primera_emision,
    estacion_canal,
    grupo_estacion,
    grupo_comercial,
    cobertura,
    categoria,
    duracion_programada_segundos,
    segundos_truncados,

    CASE
        WHEN archivo_fuente = archivo_dia2   THEN TRUE   -- dia2: siempre válido
        WHEN fecha_emision  = min_fecha_dia1 THEN TRUE   -- cayó de ventana deslizante, nunca reauditado
        WHEN en_dia2        = 0              THEN FALSE  -- falso positivo: dia1 sin confirmación en dia2
        ELSE TRUE
    END AS is_valid

FROM con_flags
WHERE rn = 1
