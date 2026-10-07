-- Lab: SQL analytics with DuckDB — exercises
-- Assumes the `users` and `orders` tables are already loaded (see lab-duckdb.md,
-- "Load the tables" section):
--   CREATE OR REPLACE TABLE users AS FROM read_csv(getvariable('bucket') || '/bronze/users.csv');
--   CREATE OR REPLACE TABLE orders AS FROM read_csv(getvariable('bucket') || '/bronze/orders.csv');

-- 1. Average number of orders per user, and average quantity per order.
SELECT
  round(count(*) * 1.0 / count(DISTINCT user_uuid), 2) AS avg_orders_per_user,
  round(avg(quantity), 2) AS avg_quantity_per_order
FROM orders;

-- 2. For each user, the date of their first and last order, and the number of days between them.
SELECT
  u.uuid,
  u.username,
  min(o.date) AS first_order,
  max(o.date) AS last_order,
  date_diff('day', min(o.date), max(o.date)) AS days_between
FROM orders o
JOIN users u ON o.user_uuid = u.uuid
GROUP BY ALL
ORDER BY days_between DESC;

-- 3. Which hour of the day has the highest quantity sold?
SELECT hour(date) AS hour_of_day, sum(quantity) AS quantity
FROM orders
GROUP BY hour_of_day
ORDER BY quantity DESC
LIMIT 1;

-- 4. For each product, the month-over-month variation of the quantity sold, in percent.
WITH monthly AS (
  SELECT date_trunc('month', date) AS month, product, sum(quantity) AS quantity
  FROM orders
  GROUP BY month, product
)
SELECT
  month,
  product,
  quantity,
  round(
    100.0 * (quantity - lag(quantity) OVER (PARTITION BY product ORDER BY month))
    / lag(quantity) OVER (PARTITION BY product ORDER BY month),
    1
  ) AS mom_variation_pct
FROM monthly
ORDER BY product, month;

-- 5. Which users ordered every product at least once?
SELECT u.uuid, u.username
FROM users u
JOIN orders o ON o.user_uuid = u.uuid
GROUP BY u.uuid, u.username
HAVING count(DISTINCT o.product) = (SELECT count(DISTINCT product) FROM orders);
