WITH spots AS (
    SELECT * FROM {{ ref('int_spots_validados') }}
)

SELECT
    *,
    CASE
        WHEN EXTRACT(HOUR FROM hora_emision) >= 18
          OR EXTRACT(HOUR FROM hora_emision) <= 1  THEN 'Primetime'
        WHEN EXTRACT(HOUR FROM hora_emision) >= 8
         AND EXTRACT(HOUR FROM hora_emision) <= 17 THEN 'Day'
        WHEN EXTRACT(HOUR FROM hora_emision) >= 2
         AND EXTRACT(HOUR FROM hora_emision) <= 7  THEN 'Greytime'
    END AS segmento_horario
FROM spots
