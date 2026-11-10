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
  {#- The password goes into a variable and from there into an mssql secret,
      so it is never part of a connection string, where a ';' would break it,
      and duckdb_secrets() shows it redacted. getvariable() rather than the
      $name shorthand, which is new in DuckDB 2.0: dbt 2 embeds 1.5.4 on Linux.
      Both statements go in one run_query, because dbt 2 may run separate calls
      on separate connections, and a session variable does not carry over. -#}
  {% do run_query("SET VARIABLE sa_password = '" ~ env_var('SA_PASSWORD') | replace("'", "''") ~ "'; CREATE OR REPLACE SECRET referensdata (TYPE mssql, host 'localhost', port " ~ env_var('MSSQL_PORT', '1433') ~ ", database 'Referensdata', user 'sa', password getvariable('sa_password'), trust_server_certificate true)") %}
  {% do run_query("ATTACH IF NOT EXISTS '' AS Referensdata (TYPE mssql, SECRET referensdata)") %}
{% endmacro %}

{#-
  dbt 2 creates schemas before on-run-start, so SQL Server has to be attached
  here for commands that create schemas. on-run-start covers the rest.
-#}
{% macro duckdb__create_schema(relation) %}
  {{ duckdb_setup() }}
  {% do run_query("create schema if not exists " ~ relation.without_identifier()) %}
{% endmacro %}
