# Lab: Bronze to Silver with dbt and DuckDB — local validation

Executed on 2026-10-07 with `dbt-duckdb` 1.11.0 / dbt-core 1.12.5 (same versions as the lab),
against local copies of `users.csv`/`orders.csv` (the `sources.yml` committed here uses the
real S3 bronze layer, as specified by the lab — the local run temporarily pointed
`external_location` at the local files to validate the SQL, then this file was restored to the
S3 version before committing).

## Gaps found in the lab text (fixed here)

- **`seeds/states.csv` is required but never shown in the lab.** `silver.yml` references
  `ref('states')` in a `relationships` test on `stg_users.state`, but the lab never creates
  this seed — `dbt test`/`dbt build` fails with "Model 'states' not found" without it. Added
  `seeds/states.csv` with the 50 states + DC + US territories + military codes (AA/AE/AP),
  since Faker's `simple_profile()` generates all of these as `state`.
- **`dbt build --select silver` does not build the `states` seed**, since seeds under
  `seeds/` aren't matched by a selector scoped to the `silver` model directory. Use
  `dbt build --select silver states zip_prefix_regions` (or just `dbt build` with no
  selector) instead.

## Core lab — all verified

- `dbt show` on `source('bronze', 'orders')` → identical rows to the lab's example.
- `stg_users` / `stg_orders` build as views, schemas match the lab exactly (UUID, TIMESTAMP
  WITH TIME ZONE, etc.), including the military-address edge case (`city` NULL for
  `DPO AP 09617`-style addresses).
- 13 generic tests (`unique`, `not_null`, `accepted_values`, `relationships`) — all PASS once
  the `states` seed exists.
- `assert_orders_have_users` (singular test) — PASS.
- `assert_orders_after_user_birth` (singular test, initially `severity='warn'`) — **288
  warnings**, matching the lab's documented number exactly (confirms this environment's
  dataset generation is bit-for-bit identical to the lab/Onyxia, same seeded Faker run).
- `dbt build --select silver states` from a clean database — full pipeline green except the
  expected warning.
- Lineage (`dbt ls --select +stg_orders`) — matches the lab's graph.
- Parquet export/read round-trip (`COPY ... TO ... FORMAT parquet`, `read_parquet`) validated
  locally on a local path (S3 path works the same way, just needs the real bucket).

## Exercises

1. **`username_normalized`** — added to `stg_users` (trim + lowercase), documented and tested
   (`not_null`) in `silver.yml`.
2. **Order validation** — `quantity` positivity: singular test `assert_orders_quantity_positive`
   (new). `product` in the expected list and `user_id` existing in `stg_users` were already
   covered by the `accepted_values`/`relationships` generic tests from the core lab.
3. **Invalid birthdates** — `stg_users` now joins the bronze `orders` source (not `stg_orders`,
   to avoid a staging-to-staging dependency) to find each user's first order, nulls out
   `birthdate` when it's after that date, and exposes `birthdate_is_valid`. After this change,
   `assert_orders_after_user_birth` genuinely returns 0 rows — the `severity='warn'` override
   was removed from the test since it's no longer needed.
4. **Invalid ZIP codes** — added `seeds/zip_prefix_regions.csv`, a reference table mapping the
   **first digit** of a US ZIP code to its valid state(s) (the standard USPS first-digit
   region split). A full 3-digit ZIP-prefix-to-state table would be more precise but has
   hundreds of entries and needs an authoritative, regularly-updated external source (USPS/
   Census); the first-digit table is small, stable, and good enough to catch gross
   inconsistencies. The new singular test `assert_zip_matches_state` **fails with 46 rows out
   of 50 users** — this is expected and intentional: the dataset generator picks the state and
   the ZIP code independently at random (the lab's own example, `KY 01352`, is exactly this
   kind of inconsistency), so the test's job here is to **detect** the issue, not to silently
   fix it, same spirit as the original `assert_orders_after_user_birth` before exercise 3.
5. **Materialization experiment** — switched `silver` to `+materialized: table`, rebuilt:
   `information_schema.tables` confirms `BASE TABLE` instead of `VIEW`. A table stores the
   data physically at build time (more storage, stale until the next `dbt run`, but queries
   don't re-read the source CSVs); a view stores only the query (no extra storage, always
   fresh, but re-executes — including the S3 `read_csv` — on every query). Restored to `view`
   before committing, as asked by the lab.
