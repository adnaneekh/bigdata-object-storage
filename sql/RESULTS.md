# Lab: SQL analytics with DuckDB — local validation

Executed on 2026-10-07 with the DuckDB **Python API** (`duckdb` package) against the local
`users.csv`/`orders.csv` (same data as the bronze layer on S3), since no DuckDB CLI binary
could be installed quickly in this environment (no prebuilt macOS bottle available, source
build too slow). The CLI-only parts of the lab (dot commands, `init.sql`, `duckdb_secrets()`,
Parquet/Hive partitioning on S3) must be run on Onyxia, where the CLI is preinstalled.

## Sanity checks

- `count(*) FROM users` → 50, `count(*) FROM orders` → 2829 (matches the lab exactly).
- `orders_report()` logic (monthly orders/quantity, no filter) →
  `2020-01 744 2297`, `2020-02 696 2154`, `2020-03 744 2192`, `2020-04 645 1972`
  — identical to the lab's expected output.

## Exercises (`sql/exercises.sql`)

1. **Avg orders/user and avg quantity/order**: `56.58` orders/user, `3.05` quantity/order.
2. **First/last order per user + days between**: top 5 by span, e.g. `hoganashlee` — 5 days
   between first and last order (query returns all 50 users; `LIMIT 5` only in this test run).
3. **Hour with highest quantity sold**: hour `6` (6am), with `385` total quantity across the
   whole dataset.
4. **Month-over-month variation per product**: validated against the `PIVOT` table in the lab
   (e.g. `bread`: 315 → 362 → 411 → 332, i.e. `+14.9%`, `+13.5%`, `-19.2%`).
5. **Users who ordered every product at least once**: 45 of the 50 users (5 users never ordered
   all 6 products).

Needed `pytz` (now a regular dependency, not dev-only — `orders_report.py` needs it too, since
DuckDB's Python client requires it for `TIMESTAMP WITH TIME ZONE` operations like
`date_diff`/`date_trunc`/`strftime`).

## Not run here (needs the real Onyxia DuckDB CLI + S3)

- `duckdb_secrets()` / the `s3_onyxia_connection` persistent secret
- `init.sql` + `getvariable('bucket')` session setup
- `sniff_csv`, `SUMMARIZE`, `DESCRIBE` on the real bronze CSVs over S3
- Parquet export (`COPY ... TO ... (FORMAT parquet)`) and Hive partitioning (`PARTITION_BY`)
- The CSV vs. Parquet scale comparison (`EXPLAIN ANALYZE`, HTTP stats) on `large/orders.csv`
- `orders-report` end-to-end against the real S3 bucket (the SQL logic itself is validated above)

Run `sql/exercises.sql` directly in the Onyxia CLI once the `users`/`orders` tables are loaded
from the bronze layer — it is 1:1 portable, no changes needed.
