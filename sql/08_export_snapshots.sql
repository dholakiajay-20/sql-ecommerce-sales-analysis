-- FILE: sql/08_export_snapshots.sql
-- Pure SQL COPY to /exports (requires the ./exports:/exports mount)

SET search_path = raw, stg, core, public;

BEGIN;

-- 1) Headline KPIs
COPY (
  SELECT * FROM core.v_kpi_headline
) TO '/exports/kpi_headline.csv' WITH (FORMAT csv, HEADER true);

-- 2) Top customers by LTV (top 50)
COPY (
  SELECT customer_id, region, payment_method, orders_count, ltv, ltv_rank
  FROM core.v_top_customers_ltv
  ORDER BY ltv DESC
  LIMIT 50
) TO '/exports/top_customers_ltv.csv' WITH (FORMAT csv, HEADER true);

-- 3) Sales by product category
COPY (
  SELECT product_category, orders, revenue, revenue_share_pct
  FROM core.v_sales_by_category
  ORDER BY revenue DESC
) TO '/exports/sales_by_category.csv' WITH (FORMAT csv, HEADER true);

-- 4) Sales by region
COPY (
  SELECT region, orders, revenue, revenue_share_pct
  FROM core.v_sales_by_region
  ORDER BY revenue DESC
) TO '/exports/sales_by_region.csv' WITH (FORMAT csv, HEADER true);

-- 5) Monthly seasonality
COPY (
  SELECT year, month, month_name, quarter, season_uk, orders, revenue, avg_order_value
  FROM core.v_seasonality_monthly
  ORDER BY year, month
) TO '/exports/seasonality_monthly.csv' WITH (FORMAT csv, HEADER true);

-- 6) Payment mix
COPY (
  SELECT payment_method, orders, revenue, aov, revenue_share_pct
  FROM core.v_payment_mix
  ORDER BY revenue DESC
) TO '/exports/payment_mix.csv' WITH (FORMAT csv, HEADER true);

-- 7) New vs repeat split
COPY (
  WITH nr AS (
    SELECT customer_order_type, COUNT(*) AS orders, ROUND(SUM(net_revenue),2) AS revenue
    FROM core.v_order_new_repeat
    GROUP BY customer_order_type
  )
  SELECT
    customer_order_type, orders, revenue,
    ROUND(100.0 * orders  / NULLIF(SUM(orders)  OVER (),0), 2) AS orders_share_pct,
    ROUND(100.0 * revenue / NULLIF(SUM(revenue) OVER (),0), 2) AS revenue_share_pct
  FROM nr
  ORDER BY customer_order_type
) TO '/exports/new_vs_repeat.csv' WITH (FORMAT csv, HEADER true);

COMMIT;

