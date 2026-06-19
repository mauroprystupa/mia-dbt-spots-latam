{% test max_distinct_values(model, column_name, max_values) %}

    -- Falla si la columna tiene más de max_values valores distintos.
    -- Uso principal: validar que staging nunca devuelve más de 2 archivos distintos.
    -- Si alguien carga un tercer archivo sin actualizar la lógica, este test
    -- falla explícitamente en lugar de corromperse silenciosamente.
    SELECT COUNT(DISTINCT {{ column_name }}) AS n_distinct
    FROM {{ model }}
    HAVING COUNT(DISTINCT {{ column_name }}) > {{ max_values }}

{% endtest %}
