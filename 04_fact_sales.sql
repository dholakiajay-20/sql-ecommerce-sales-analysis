-- 04_fact_sales.sql
-- Purpose: Build fact table at order line grain for purchases only.

-- Sections:
-- 1) Filter stg_orders where interaction_type='purchase'
-- 2) Generate surrogate order_id = hash(user_id, product_id, event_ts)
-- 3) Join with dim_product to get unit_price (selling_price); default quantity=1
-- 4) Compute derived measures: gross_item_value, net_revenue
-- 5) Join dim_customer, dim_calendar, dim_region
-- 6) Exclude rows with missing product price or keys (log to dq table)
-- 7) Final schema: fact_sales(...columns...) with constraints

-- FILE: sql/04_fact_sales.sql
-- WHY: Build purchase-line fact table with derived revenue metrics and denormalized attrs.
-- FILE: sql/04_fact_sales.sql
-- PURPOSE: Build fact across ALL purchases (no 2024 filter), with derived revenue fields.

SET search_path = raw, stg, core, public;

DROP TABLE IF EXISTS core.fact_sales;

CREATE TABLE core.fact_sales AS
WITH purchases AS (
  SELECT
    o.user_id        AS customer_id,
    o.product_id     AS product_id,
    o.event_ts       AS event_ts,
    o.event_date     AS order_date
  FROM stg.stg_orders o
  WHERE o.interaction_type = 'purchase'
),
joined AS (
  SELECT
    md5( concat_ws('::', p.customer_id::text, p.product_id::text, p.event_ts::text) ) AS order_id,
    p.order_date,
    p.customer_id,
    p.product_id,
    1::int AS quantity,
    dp.selling_price::numeric(10,2) AS unit_price,
    dc.region,
    dc.payment_method
  FROM purchases p
  JOIN core.dim_product  dp ON dp.product_id  = p.product_id
  JOIN core.dim_customer dc ON dc.customer_id = p.customer_id
  JOIN core.dim_calendar dcal ON dcal.date    = p.order_date
)
SELECT
  j.order_id,
  j.order_date,
  j.customer_id,
  j.product_id,
  j.quantity,
  j.unit_price,
  (j.quantity * j.unit_price)::numeric(12,2) AS gross_item_value,
  0::numeric(10,2) AS discount_amount,
  0::numeric(10,2) AS tax_amount,
  0::numeric(10,2) AS shipping_fee,
  (j.quantity * j.unit_price)::numeric(12,2) AS net_revenue,
  j.region,
  j.payment_method,
  now()::timestamptz AS created_at
FROM joined j
WHERE j.unit_price IS NOT NULL
  AND j.unit_price > 0
;

ALTER TABLE core.fact_sales ADD PRIMARY KEY (order_id);

CREATE INDEX IF NOT EXISTS idx_fact_sales_date      ON core.fact_sales(order_date);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer  ON core.fact_sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product   ON core.fact_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_region    ON core.fact_sales(region);
CREATE INDEX IF NOT EXISTS idx_fact_sales_paymethod ON core.fact_sales(payment_method);

-- Sanity (cast to text so UNION works)
SELECT * FROM (
  SELECT 'fact_sales'::text         AS metric, COUNT(*)::text                           AS value FROM core.fact_sales
  UNION ALL SELECT 'distinct_customers',          COUNT(DISTINCT customer_id)::text     FROM core.fact_sales
  UNION ALL SELECT 'distinct_products',           COUNT(DISTINCT product_id)::text      FROM core.fact_sales
  UNION ALL SELECT 'min_date',                    MIN(order_date)::text                 FROM core.fact_sales
  UNION ALL SELECT 'max_date',                    MAX(order_date)::text                 FROM core.fact_sales
) s;
