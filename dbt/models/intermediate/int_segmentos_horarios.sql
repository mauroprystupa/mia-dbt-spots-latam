WITH spots AS (
    SELECT * FROM {{ ref('int_spots_validados') }}
)

SELECT
    *,
    CASE
        -- Primetime cruza medianoche: 18:00–01:59.
        -- OR en lugar de BETWEEN porque el rango no es continuo dentro del mismo día.
        WHEN EXTRACT(HOUR FROM hora_emision) >= 18
          OR EXTRACT(HOUR FROM hora_emision) <= 1  THEN 'Primetime'
        WHEN EXTRACT(HOUR FROM hora_emision) >= 8
         AND EXTRACT(HOUR FROM hora_emision) <= 17 THEN 'Day'
        -- Greytime arranca en hora 2. Las 02:00 no son Primetime — decisión de negocio.
        WHEN EXTRACT(HOUR FROM hora_emision) >= 2
         AND EXTRACT(HOUR FROM hora_emision) <= 7  THEN 'Greytime'
    END AS segmento_horario
FROM spots
