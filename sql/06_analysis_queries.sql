-- =========================
-- FILE: sql/06_analysis_queries.sql
-- PURPOSE: Snapshot queries to generate CSVs/plots for README.
-- =========================

SET search_path = raw, stg, core, public;

-- 1) Headline KPIs
-- Tip: Use this to populate KPI strip in README
SELECT * FROM core.v_kpi_headline;

-- 2) Top 10 customers by LTV
SELECT customer_id, region, payment_method, orders_count, ltv, ltv_rank
FROM core.v_top_customers_ltv
ORDER BY ltv DESC
LIMIT 10;

-- 3) Revenue & share by product category
SELECT product_category, orders, revenue, revenue_share_pct
FROM core.v_sales_by_category;

-- 4) Monthly revenue, AOV, and season
SELECT year, month, month_name, quarter, season_uk, orders, revenue, avg_order_value
FROM core.v_seasonality_monthly;

-- 5) Revenue by region
SELECT region, orders, revenue, revenue_share_pct
FROM core.v_sales_by_region;

-- 6) Payment method revenue & AOV
SELECT payment_method, orders, revenue, aov, revenue_share_pct
FROM core.v_payment_mix;

-- 7) New vs repeat split (orders & revenue)
WITH nr AS (
  SELECT
    customer_order_type,
    COUNT(*)                              AS orders,
    ROUND(SUM(net_revenue),2)             AS revenue
  FROM core.v_order_new_repeat
  GROUP BY customer_order_type
)
SELECT
  customer_order_type,
  orders,
  revenue,
  ROUND(100.0 * orders  / NULLIF(SUM(orders)  OVER (),0), 2) AS orders_share_pct,
  ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (),0), 2) AS revenue_share_pct
FROM nr
ORDER BY customer_order_type;

