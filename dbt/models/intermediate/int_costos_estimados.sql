WITH spots AS (
    SELECT * FROM {{ ref('int_segmentos_horarios') }}
),

-- Nivel 1: promedio por (mercado, medio, segmento_horario) — granularidad máxima
-- Solo spots válidos con costo real conocido
promedios_grupo AS (
    SELECT
        mercado,
        medio,
        segmento_horario,
        AVG(costo_usd_real) AS avg_costo
    FROM spots
    WHERE costo_usd_real IS NOT NULL
      AND is_valid = TRUE
    GROUP BY 1, 2, 3
),

-- Nivel 2: fallback cross-mercado por (medio, segmento_horario)
-- Necesario porque México tiene 100% NULL. También cubre Brasil RADIO_AM (sin costos reales).
promedios_medio_segmento AS (
    SELECT
        medio,
        segmento_horario,
        AVG(costo_usd_real) AS avg_costo
    FROM spots
    WHERE costo_usd_real IS NOT NULL
      AND is_valid = TRUE
    GROUP BY 1, 2
),

-- Nivel 3: fallback por segmento_horario puro
-- Garantiza no-NULL si un segmento no tiene costo real en ningún mercado ni medio.
promedios_segmento AS (
    SELECT
        segmento_horario,
        AVG(costo_usd_real) AS avg_costo
    FROM spots
    WHERE costo_usd_real IS NOT NULL
      AND is_valid = TRUE
    GROUP BY 1
)

SELECT
    s.*,
    COALESCE(
        pg.avg_costo,
        pms.avg_costo,
        ps.avg_costo
    ) AS costo_usd_estimado,
    COALESCE(
        s.costo_usd_real,
        pg.avg_costo,
        pms.avg_costo,
        ps.avg_costo
    ) AS costo_usd_final
FROM spots s
LEFT JOIN promedios_grupo pg
    ON s.mercado          = pg.mercado
   AND s.medio            = pg.medio
   AND s.segmento_horario = pg.segmento_horario
LEFT JOIN promedios_medio_segmento pms
    ON s.medio            = pms.medio
   AND s.segmento_horario = pms.segmento_horario
LEFT JOIN promedios_segmento ps
    ON s.segmento_horario = ps.segmento_horario
