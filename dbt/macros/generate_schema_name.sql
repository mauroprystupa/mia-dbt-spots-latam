-- Sobreescribe el comportamiento default de dbt para naming de datasets.
-- Sin esta macro, dbt concatena el schema default del profile con el schema
-- custom del modelo: "dev_mia_staging" en lugar de "mia_staging".
{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- if custom_schema_name is none -%}
    {{ default_schema }}
  {%- else -%}
    {{ custom_schema_name | trim }}
  {%- endif -%}
{%- endmacro %}
