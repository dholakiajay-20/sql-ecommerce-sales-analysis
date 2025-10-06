-- 05_kpi_views.sql
-- Purpose: Expose reusable KPI views for dashboards and analysis.

-- Sections:
-- 1) v_kpi_headline (net_revenue, orders, customers, AOV, repeat_rate)
-- 2) v_top_customers_ltv (ltv, orders_per_customer)
-- 3) v_sales_by_category (revenue, share, trend)
-- 4) v_sales_by_region (revenue, share)
-- 5) v_seasonality (month/season metrics)
-- 6) v_payment_mix (by payment_method from dim_customer)
-- 7) v_retention (new vs repeat flags per order/customer)

-- =========================
-- FILE: sql/05_kpi_views.sql
-- PURPOSE: Reusable KPI views across ALL data (no year filter).
-- =========================

SET search_path = raw, stg, core, public;

-- 0) Safety: ensure base tables exist
-- (no-op selects will error early if a dependency is missing)
SELECT 1 FROM core.fact_sales  LIMIT 1;
SELECT 1 FROM core.dim_product LIMIT 1;
SELECT 1 FROM core.dim_customer LIMIT 1;
SELECT 1 FROM core.dim_calendar LIMIT 1;

-- 1) Headline KPIs (overall)
DROP VIEW IF EXISTS core.v_kpi_headline;
CREATE VIEW core.v_kpi_headline AS
WITH base AS (
  SELECT
    COUNT(*)::bigint                                   AS orders,
    COUNT(DISTINCT customer_id)::bigint                AS customers,
    COUNT(DISTINCT product_id)::bigint                 AS products,
    COALESCE(SUM(net_revenue),0)::numeric(14,2)        AS net_revenue,
    MIN(order_date)                                    AS min_date,
    MAX(order_date)                                    AS max_date
  FROM core.fact_sales
)
SELECT
  orders,
  customers,
  products,
  net_revenue,
  CASE WHEN orders > 0 THEN ROUND(net_revenue / orders, 2) ELSE 0 END AS aov,
  min_date,
  max_date
FROM base;

-- 2) Top customers by LTV (revenue-only)
DROP VIEW IF EXISTS core.v_top_customers_ltv;
CREATE VIEW core.v_top_customers_ltv AS
SELECT
  fs.customer_id,
  dc.region,
  dc.payment_method,
  MIN(fs.order_date)                          AS first_order_date,
  MAX(fs.order_date)                          AS last_order_date,
  COUNT(*)                                    AS orders_count,
  ROUND(SUM(fs.net_revenue),2)                AS ltv,
  DENSE_RANK() OVER (ORDER BY SUM(fs.net_revenue) DESC) AS ltv_rank
FROM core.fact_sales fs
LEFT JOIN core.dim_customer dc ON dc.customer_id = fs.customer_id
GROUP BY fs.customer_id, dc.region, dc.payment_method;

-- 3) Sales by product category
DROP VIEW IF EXISTS core.v_sales_by_category;
CREATE VIEW core.v_sales_by_category AS
WITH cat AS (
  SELECT
    dp.product_category,
    COUNT(*)                          AS orders,
    ROUND(SUM(fs.net_revenue),2)      AS revenue
  FROM core.fact_sales fs
  JOIN core.dim_product dp ON dp.product_id = fs.product_id
  GROUP BY dp.product_category
)
SELECT
  product_category,
  orders,
  revenue,
  ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (),0), 2) AS revenue_share_pct
FROM cat
ORDER BY revenue DESC;

-- 4) Sales by region
DROP VIEW IF EXISTS core.v_sales_by_region;
CREATE VIEW core.v_sales_by_region AS
WITH r AS (
  SELECT
    COALESCE(fs.region,'Unknown')      AS region,
    COUNT(*)                           AS orders,
    ROUND(SUM(fs.net_revenue),2)       AS revenue
  FROM core.fact_sales fs
  GROUP BY COALESCE(fs.region,'Unknown')
)
SELECT
  region,
  orders,
  revenue,
  ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (),0), 2) AS revenue_share_pct
FROM r
ORDER BY revenue DESC;

-- 5) Seasonality (monthly + season from calendar)
DROP VIEW IF EXISTS core.v_seasonality_monthly;
CREATE VIEW core.v_seasonality_monthly AS
SELECT
  c.year,
  c.month,
  c.month_name,
  c.quarter,
  c.season_uk,
  COUNT(fs.order_id)                             AS orders,
  ROUND(SUM(fs.net_revenue),2)                   AS revenue,
  ROUND(AVG(fs.net_revenue),2)                   AS avg_order_value
FROM core.fact_sales fs
JOIN core.dim_calendar c ON c.date = fs.order_date
GROUP BY c.year, c.month, c.month_name, c.quarter, c.season_uk
ORDER BY c.year, c.month;

-- 6) Payment mix (revenue + AOV)
DROP VIEW IF EXISTS core.v_payment_mix;
CREATE VIEW core.v_payment_mix AS
WITH pm AS (
  SELECT
    COALESCE(fs.payment_method,'other')          AS payment_method,
    COUNT(*)                                     AS orders,
    ROUND(SUM(fs.net_revenue),2)                 AS revenue
  FROM core.fact_sales fs
  GROUP BY COALESCE(fs.payment_method,'other')
)
SELECT
  payment_method,
  orders,
  revenue,
  CASE WHEN orders>0 THEN ROUND(revenue/orders,2) ELSE 0 END AS aov,
  ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (),0), 2) AS revenue_share_pct
FROM pm
ORDER BY revenue DESC;

-- 7) First purchase per customer (helper)
DROP VIEW IF EXISTS core.v_customer_first_purchase;
CREATE VIEW core.v_customer_first_purchase AS
SELECT
  customer_id,
  MIN(order_date) AS first_purchase_date
FROM core.fact_sales
GROUP BY customer_id;

-- 8) New vs Repeat flag at order level
DROP VIEW IF EXISTS core.v_order_new_repeat;
CREATE VIEW core.v_order_new_repeat AS
SELECT
  fs.*,
  CASE
    WHEN fs.order_date = cfp.first_purchase_date THEN 'new'
    ELSE 'repeat'
  END AS customer_order_type
FROM core.fact_sales fs
JOIN core.v_customer_first_purchase cfp
  ON cfp.customer_id = fs.customer_id;

-- 9) Customer repeat windows (2nd order timing)
DROP VIEW IF EXISTS core.v_customer_repeat_windows;
CREATE VIEW core.v_customer_repeat_windows AS
WITH ranked AS (
  SELECT
    customer_id,
    order_date,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM core.fact_sales
),
first_second AS (
  SELECT
    f.customer_id,
    f.order_date AS first_order_date,
    s.order_date AS second_order_date,
    CASE
      WHEN s.order_date IS NULL THEN NULL
      ELSE (s.order_date - f.order_date)
    END AS days_to_second
  FROM ranked f
  LEFT JOIN ranked s
    ON s.customer_id = f.customer_id AND s.rn = 2
  WHERE f.rn = 1
)
SELECT
  customer_id,
  first_order_date,
  second_order_date,
  days_to_second,
  (days_to_second <= 30)::boolean AS repeat_30d,
  (days_to_second <= 60)::boolean AS repeat_60d,
  (days_to_second <= 90)::boolean AS repeat_90d
FROM first_second;

-- 10) Quick sanity selects (optional)
SELECT * FROM core.v_kpi_headline;
SELECT * FROM core.v_sales_by_category LIMIT 10;
SELECT * FROM core.v_sales_by_region;
SELECT * FROM core.v_seasonality_monthly;
SELECT * FROM core.v_payment_mix;
SELECT * FROM core.v_top_customers_ltv ORDER BY ltv DESC LIMIT 10;


