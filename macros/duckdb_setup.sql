{#-
  dbt 2's built-in DuckDB can use the community mssql extension, but its
  profile cannot set it up: `extensions:` only takes plain names, which
  install from the core repository, and `attach:` runs after them. So this
  macro does the INSTALL, LOAD and ATTACH itself.
-#}
{% macro duckdb_setup() %}
  {% do run_query("INSTALL mssql FROM community") %}
  {% do run_query("LOAD mssql") %}
  {% do run_query("INSTALL httpfs") %}
  {% do run_query("LOAD httpfs") %}
  {% do run_query("INSTALL azure") %}
  {% do run_query("LOAD azure") %}
  {% do run_query("SET GLOBAL azure_transport_option_type = 'curl'") %}
  {% do run_query("SET GLOBAL ca_cert_file = '" ~ env_var('AZURE_CA_CERT_FILE', '/etc/ssl/certs/ca-certificates.crt') ~ "'") %}
  {% do run_query("CREATE OR REPLACE SECRET azure_open (TYPE azure, PROVIDER config, ACCOUNT_NAME 'azureopendatastorage')") %}
  {% do run_query("ATTACH IF NOT EXISTS 'Server=localhost,1433;Database=Referensdata;UID=sa;PWD=" ~ env_var('SA_PASSWORD') ~ ";Encrypt=yes;TrustServerCertificate=yes' AS Referensdata (TYPE mssql)") %}
{% endmacro %}

{#-
  dbt 2 creates schemas before on-run-start, so SQL Server has to be attached
  here for commands that create schemas. on-run-start covers the rest.
-#}
{% macro duckdb__create_schema(relation) %}
  {{ duckdb_setup() }}
  {% do run_query("create schema if not exists " ~ relation.without_identifier()) %}
{% endmacro %}
