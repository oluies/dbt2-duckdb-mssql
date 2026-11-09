# dbt 2 on SQL Server through DuckDB

dbt v2 has no SQL Server adapter, but it has DuckDB built in. DuckDB's community [`mssql` extension](https://github.com/hugr-lab/mssql-extension) can write to SQL Server. This repository tests whether the two can be combined, using a real project: the date dimension, holiday calendar and exchange calendar from [dbt-duckdb-trading-calendar](https://github.com/oluies/dbt-duckdb-trading-calendar).

They can. With `dbt-oss` 2.0.11 and its embedded DuckDB v2.0.0, all seeds and models build into SQL Server and all 69 data tests pass. This is an experiment and is not supported by dbt Labs or Microsoft.

| Feature | Result on dbt 2 |
| --- | --- |
| Seeds and table models written to SQL Server | Works |
| Generic and singular tests, `dbt_utils` 1.3.0 | Works |
| Ephemeral models, `dbt_utils.date_spine` | Works |
| Reading Parquet from Azure with the `azure` extension | Works |
| Default static analysis on DuckDB SQL | No objections |
| Loading an unsigned extension (`cpt`) | Does not work; see below |

## The workaround

dbt 2's profile cannot set the extension up. `extensions:` accepts only plain names, so it installs `mssql` from the core repository and fails. The project does the work in [`macros/duckdb_setup.sql`](macros/duckdb_setup.sql) instead:

- `duckdb_setup()` runs `INSTALL mssql FROM community`, `LOAD mssql` and `ATTACH ... (TYPE mssql)`.
- dbt 2 creates schemas before `on-run-start`, so the macro overrides `duckdb__create_schema` to attach SQL Server first.
- `on-run-start` calls it too, for commands such as `dbt test` that create no schemas.

Models then write to SQL Server with `+database: Referensdata`, as they did on dbt 1. The override depends on the order dbt 2 runs things in, so CI runs every week to catch a change.

## What changed from dbt 1

- `requirements.txt` installs `dbt-oss` in place of `dbt-core` and `dbt-duckdb`.
- `profiles.yml` has only `type`, `path`, `schema` and `threads`. Extensions, settings, secrets and the attachment moved to the macro.
- Generic test arguments moved under `arguments:`, and the deprecated `target-path` is gone. Both were done by `dbt-autofix`, which needs a Python its dependencies support (3.12 worked; 3.15 did not).
- The Elementary package is left out, because it is not on the list of packages dbt Labs says work on v2.

## What does not work yet

The change point models in `models/changepoint/` are copied over but switched off. They need the [`cpt`](https://github.com/hugr-lab/duck-changepoint) extension, which is a local unsigned build. DuckDB only accepts `allow_unsigned_extensions` at startup. dbt 2 applies its `settings:` after startup, so DuckDB rejects it, and no other profile key tried so far takes effect. Publishing `cpt` as a signed community extension would remove the problem.

Azure SQL Edge (Apple Silicon) was used for local testing, and SQL Server 2022 is used in CI.

## Running it

Needs Docker and Python 3.10 or later.

```bash
cp .env.example .env          # set SA_PASSWORD
make db-up                    # Apple Silicon: make PLATFORM=arm-mac db-up
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
make db-init                  # Apple Silicon: make PLATFORM=arm-mac db-init

export DBT_PROFILES_DIR=$PWD
set -a; source .env; set +a   # dbt reads SA_PASSWORD from the environment
dbt deps && dbt seed && dbt run && dbt test
```

On macOS, set `AZURE_CA_CERT_FILE=/etc/ssl/cert.pem` in `.env`.
