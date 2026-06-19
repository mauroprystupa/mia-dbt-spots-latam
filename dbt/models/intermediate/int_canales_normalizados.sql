WITH spots AS (
    SELECT * FROM {{ ref('int_costos_estimados') }}
),

ref AS (
    SELECT * FROM {{ source('mia_ref', 'ref_canales') }}
)

SELECT
    s.*,
    COALESCE(r.canal_normalizado, s.canal_raw) AS canal_normalizado,
    r.grupo_canal
FROM spots s
LEFT JOIN ref r
    ON s.canal_raw = r.canal_raw
   AND s.mercado   = r.mercado
