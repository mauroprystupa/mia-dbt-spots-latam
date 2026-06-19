WITH spots AS (
    SELECT * FROM {{ ref('int_canales_normalizados') }}
),

ref AS (
    SELECT * FROM {{ source('mia_ref', 'ref_marcas') }}
)

SELECT
    s.*,
    COALESCE(r.marca_comercial, s.marca_raw) AS marca_comercial
FROM spots s
LEFT JOIN ref r
    ON s.marca_raw = r.marca_raw
