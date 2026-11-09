{% macro load_cpt() %}
  {#- Pre-hook of fct_fx_regimes: cpt is a signed community extension. -#}
  {% do run_query("INSTALL cpt FROM community") %}
  {% do run_query("LOAD cpt") %}
{% endmacro %}
