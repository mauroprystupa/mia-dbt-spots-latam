SELECT
    -- identidad
    mercado,
    archivo_fuente,
    fecha_emision,
    hora_emision,
    segmento_horario,
    medio,

    -- canal
    canal_raw,
    canal_normalizado,
    grupo_canal,
    localidad,

    -- spot
    spot_tipo,
    marca_raw,
    marca_comercial,
    producto,
    version,
    sector,
    subsector,
    duracion_segundos,

    -- costos
    costo_usd_real,
    costo_usd_estimado,
    costo_usd_final,

    -- auditoría
    is_valid,
    updated_at

FROM {{ ref('int_marcas_normalizadas') }}
