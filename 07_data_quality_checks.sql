-- 07_data_quality_checks.sql
-- Purpose: Deterministic checks to validate the pipeline.

-- Sections:
-- 1) Row counts per table (raw → stg → dims/fact)
-- 2) Uniqueness checks on keys (customer_id, product_id, order_id)
-- 3) Referential integrity (fact has matching dim keys)
-- 4) Domain checks (interaction_type in set; prices >= 0)
-- 5) Orphan rows captured (counts & sample)
-- 6) Timeliness (all fact rows in 2024)
-- 7) Summary table v_dq_summary with pass/fail flags

-- FILE: sql/07_data_quality_checks.sql
-- PURPOSE: End-to-end data quality checks + summary view.

SET search_path = raw, stg, core, public;

-- 1) Quick row counts (visibility)
WITH counts AS (
  SELECT 'raw.customers_raw'::text AS t, COUNT(*)::bigint AS n FROM raw.customers_raw
  UNION ALL SELECT 'raw.products_raw', COUNT(*) FROM raw.products_raw
  UNION ALL SELECT 'raw.orders_raw', COUNT(*) FROM raw.orders_raw
  UNION ALL SELECT 'stg.stg_customers', COUNT(*) FROM stg.stg_customers
  UNION ALL SELECT 'stg.stg_products', COUNT(*) FROM stg.stg_products
  UNION ALL SELECT 'stg.stg_orders', COUNT(*) FROM stg.stg_orders
  UNION ALL SELECT 'core.dim_customer', COUNT(*) FROM core.dim_customer
  UNION ALL SELECT 'core.dim_product', COUNT(*) FROM core.dim_product
  UNION ALL SELECT 'core.dim_calendar', COUNT(*) FROM core.dim_calendar
  UNION ALL SELECT 'core.fact_sales', COUNT(*) FROM core.fact_sales
)
SELECT * FROM counts ORDER BY t;

-- 2) Uniqueness checks
WITH dupe_customers AS (
  SELECT customer_id FROM core.dim_customer GROUP BY customer_id HAVING COUNT(*) > 1
),
dupe_products AS (
  SELECT product_id FROM core.dim_product GROUP BY product_id HAVING COUNT(*) > 1
),
dupe_orders AS (
  SELECT order_id FROM core.fact_sales GROUP BY order_id HAVING COUNT(*) > 1
)
SELECT 'dupe_dim_customer' AS check_name, COUNT(*) AS offenders FROM dupe_customers
UNION ALL SELECT 'dupe_dim_product', COUNT(*) FROM dupe_products
UNION ALL SELECT 'dupe_fact_sales_order_id', COUNT(*) FROM dupe_orders
;

-- 3) Referential integrity (orphans; should be 0)
WITH orphan_cust AS (
  SELECT f.order_id FROM core.fact_sales f
  LEFT JOIN core.dim_customer c ON c.customer_id = f.customer_id
  WHERE c.customer_id IS NULL
),
orphan_prod AS (
  SELECT f.order_id FROM core.fact_sales f
  LEFT JOIN core.dim_product p ON p.product_id = f.product_id
  WHERE p.product_id IS NULL
),
orphan_date AS (
  SELECT f.order_id FROM core.fact_sales f
  LEFT JOIN core.dim_calendar d ON d.date = f.order_date
  WHERE d.date IS NULL
)
SELECT 'fact→dim_customer_orphans' AS check_name, COUNT(*) AS offenders FROM orphan_cust
UNION ALL SELECT 'fact→dim_product_orphans', COUNT(*) FROM orphan_prod
UNION ALL SELECT 'fact→dim_calendar_orphans', COUNT(*) FROM orphan_date
;

-- 4) Domain checks
WITH bad_interactions AS (
  SELECT COUNT(*) AS n_bad
  FROM stg.stg_orders
  WHERE interaction_type NOT IN ('purchase','view','like') OR interaction_type IS NULL
),
bad_prices AS (
  SELECT COUNT(*) AS n_bad
  FROM stg.stg_products
  WHERE selling_price IS NULL OR selling_price <= 0
),
neg_net_revenue AS (
  SELECT COUNT(*) AS n_bad
  FROM core.fact_sales
  WHERE net_revenue < 0
)
SELECT 'invalid_interaction_type' AS check_name, (SELECT n_bad FROM bad_interactions) AS offenders
UNION ALL SELECT 'invalid_or_missing_price', (SELECT n_bad FROM bad_prices)
UNION ALL SELECT 'negative_net_revenue', (SELECT n_bad FROM neg_net_revenue)
;

-- 5) Temporal checks (fact dates within calendar)
WITH bounds AS (
  SELECT MIN(date) AS min_cal, MAX(date) AS max_cal FROM core.dim_calendar
),
out_of_range AS (
  SELECT COUNT(*) AS n_bad
  FROM core.fact_sales f, bounds b
  WHERE f.order_date < b.min_cal OR f.order_date > b.max_cal
)
SELECT 'fact_dates_outside_calendar' AS check_name, (SELECT n_bad FROM out_of_range) AS offenders;

-- 6) Summary view (single place to look)
DROP VIEW IF EXISTS core.v_dq_summary;
CREATE VIEW core.v_dq_summary AS
WITH
counts AS (
  SELECT 'rows_raw_customers' AS metric, COUNT(*)::text AS value, (COUNT(*)>0) AS pass FROM raw.customers_raw
  UNION ALL SELECT 'rows_raw_products', COUNT(*)::text, (COUNT(*)>0) FROM raw.products_raw
  UNION ALL SELECT 'rows_raw_orders', COUNT(*)::text, (COUNT(*)>0) FROM raw.orders_raw
  UNION ALL SELECT 'rows_stg_customers', COUNT(*)::text, (COUNT(*)>0) FROM stg.stg_customers
  UNION ALL SELECT 'rows_stg_products', COUNT(*)::text, (COUNT(*)>0) FROM stg.stg_products
  UNION ALL SELECT 'rows_stg_orders', COUNT(*)::text, (COUNT(*)>0) FROM stg.stg_orders
  UNION ALL SELECT 'rows_dim_customer', COUNT(*)::text, (COUNT(*)>0) FROM core.dim_customer
  UNION ALL SELECT 'rows_dim_product', COUNT(*)::text, (COUNT(*)>0) FROM core.dim_product
  UNION ALL SELECT 'rows_dim_calendar', COUNT(*)::text, (COUNT(*)>0) FROM core.dim_calendar
  UNION ALL SELECT 'rows_fact_sales', COUNT(*)::text, (COUNT(*)>0) FROM core.fact_sales
),
uniques AS (
  SELECT 'dupe_dim_customer' AS metric, COUNT(*)::text AS value, (COUNT(*)=0) AS pass
  FROM (SELECT customer_id FROM core.dim_customer GROUP BY customer_id HAVING COUNT(*)>1) x
  UNION ALL
  SELECT 'dupe_dim_product', COUNT(*)::text, (COUNT(*)=0)
  FROM (SELECT product_id FROM core.dim_product GROUP BY product_id HAVING COUNT(*)>1) y
  UNION ALL
  SELECT 'dupe_fact_sales_order_id', COUNT(*)::text, (COUNT(*)=0)
  FROM (SELECT order_id FROM core.fact_sales GROUP BY order_id HAVING COUNT(*)>1) z
),
ri AS (
  SELECT 'fact→dim_customer_orphans' AS metric, COUNT(*)::text AS value, (COUNT(*)=0) AS pass
  FROM (
    SELECT 1 FROM core.fact_sales f LEFT JOIN core.dim_customer c ON c.customer_id=f.customer_id
    WHERE c.customer_id IS NULL
  ) q
  UNION ALL
  SELECT 'fact→dim_product_orphans', COUNT(*)::text, (COUNT(*)=0)
  FROM (
    SELECT 1 FROM core.fact_sales f LEFT JOIN core.dim_product p ON p.product_id=f.product_id
    WHERE p.product_id IS NULL
  ) q2
  UNION ALL
  SELECT 'fact→dim_calendar_orphans', COUNT(*)::text, (COUNT(*)=0)
  FROM (
    SELECT 1 FROM core.fact_sales f LEFT JOIN core.dim_calendar d ON d.date=f.order_date
    WHERE d.date IS NULL
  ) q3
),
domain AS (
  SELECT 'invalid_interaction_type' AS metric,
         (SELECT COUNT(*) FROM stg.stg_orders WHERE interaction_type NOT IN ('purchase','view','like') OR interaction_type IS NULL)::text AS value,
         ((SELECT COUNT(*) FROM stg.stg_orders WHERE interaction_type NOT IN ('purchase','view','like') OR interaction_type IS NULL)=0) AS pass
  UNION ALL
  SELECT 'invalid_or_missing_price',
         (SELECT COUNT(*) FROM stg.stg_products WHERE selling_price IS NULL OR selling_price<=0)::text,
         ((SELECT COUNT(*) FROM stg.stg_products WHERE selling_price IS NULL OR selling_price<=0)=0)
  UNION ALL
  SELECT 'negative_net_revenue',
         (SELECT COUNT(*) FROM core.fact_sales WHERE net_revenue<0)::text,
         ((SELECT COUNT(*) FROM core.fact_sales WHERE net_revenue<0)=0)
),
temporal AS (
  SELECT 'fact_dates_outside_calendar' AS metric,
         (
           WITH bounds AS (SELECT MIN(date) AS min_cal, MAX(date) AS max_cal FROM core.dim_calendar)
           SELECT COUNT(*) FROM core.fact_sales f, bounds b
           WHERE f.order_date < b.min_cal OR f.order_date > b.max_cal
         )::text AS value,
         (
           WITH bounds AS (SELECT MIN(date) AS min_cal, MAX(date) AS max_cal FROM core.dim_calendar)
           SELECT COUNT(*)=0 FROM core.fact_sales f, bounds b
           WHERE f.order_date < b.min_cal OR f.order_date > b.max_cal
         ) AS pass
)
SELECT * FROM counts
UNION ALL SELECT * FROM uniques
UNION ALL SELECT * FROM ri
UNION ALL SELECT * FROM domain
UNION ALL SELECT * FROM temporal
ORDER BY metric;

-- 7) View summary
SELECT * FROM core.v_dq_summary;

-- 8) Optional samples (top 5 offenders) for debugging
-- SELECT * FROM stg.stg_dq_invalid_price LIMIT 5;
-- SELECT * FROM stg.stg_dq_orphans_products LIMIT 5;
-- SELECT * FROM stg.stg_dq_orphans_customers LIMIT 5;
