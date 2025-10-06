-- 03_dimensions.sql
-- Purpose: Build conformed dimensions from staging.

-- Sections:
-- 1) dim_customer (distinct customer_id; carry attributes: gender, location, payment_method, subscription_status, etc.)
-- 2) dim_product (product_id, product_name, product_category, brand_name if present)
-- 3) dim_calendar (cover 2024 with date, month, quarter, season [UK], week_of_year)
-- 4) dim_region (US state → Region: West/Midwest/South/Northeast; Unknown fallback)


-- FILE: sql/03_dimensions.sql
-- PURPOSE: Conformed dimensions (region, dynamic calendar, product, customer) across ALL data.

SET search_path = raw, stg, core, public;

-- 1) Region
DROP TABLE IF EXISTS core.dim_region;
CREATE TABLE core.dim_region (
  state_name TEXT PRIMARY KEY,
  region TEXT NOT NULL
);

INSERT INTO core.dim_region (state_name, region) VALUES
-- Northeast
('Connecticut','Northeast'), ('Maine','Northeast'), ('Massachusetts','Northeast'),
('New Hampshire','Northeast'), ('Rhode Island','Northeast'), ('Vermont','Northeast'),
('New Jersey','Northeast'), ('New York','Northeast'), ('Pennsylvania','Northeast'),
-- Midwest
('Illinois','Midwest'), ('Indiana','Midwest'), ('Michigan','Midwest'), ('Ohio','Midwest'),
('Wisconsin','Midwest'), ('Iowa','Midwest'), ('Kansas','Midwest'), ('Minnesota','Midwest'),
('Missouri','Midwest'), ('Nebraska','Midwest'), ('North Dakota','Midwest'), ('South Dakota','Midwest'),
-- South
('Delaware','South'), ('Florida','South'), ('Georgia','South'), ('Maryland','South'),
('North Carolina','South'), ('South Carolina','South'), ('Virginia','South'),
('District of Columbia','South'), ('West Virginia','South'),
('Alabama','South'), ('Kentucky','South'), ('Mississippi','South'), ('Tennessee','South'),
('Arkansas','South'), ('Louisiana','South'), ('Oklahoma','South'), ('Texas','South'),
-- West
('Arizona','West'), ('Colorado','West'), ('Idaho','West'), ('Montana','West'),
('Nevada','West'), ('New Mexico','West'), ('Utah','West'), ('Wyoming','West'),
('Alaska','West'), ('California','West'), ('Hawaii','West'), ('Oregon','West'), ('Washington','West');

-- 2) Dynamic Calendar (min→max event_date in staging; safe fallback)
DROP TABLE IF EXISTS core.dim_calendar;
CREATE TABLE core.dim_calendar AS
WITH bounds AS (
  SELECT
    COALESCE(date_trunc('year', MIN(event_date))::date, '2020-01-01'::date) AS start_date,
    COALESCE((date_trunc('year', MAX(event_date)) + interval '1 year' - interval '1 day')::date, '2025-12-31'::date) AS end_date
  FROM stg.stg_orders
)
SELECT
  d::date AS date,
  EXTRACT(YEAR  FROM d)::INT AS year,
  EXTRACT(MONTH FROM d)::INT AS month,
  to_char(d, 'Mon') AS month_name,
  EXTRACT(QUARTER FROM d)::INT AS quarter,
  EXTRACT(WEEK FROM d)::INT AS week_of_year,
  CASE
    WHEN EXTRACT(MONTH FROM d) IN (12,1,2) THEN 'Winter'
    WHEN EXTRACT(MONTH FROM d) IN (3,4,5)  THEN 'Spring'
    WHEN EXTRACT(MONTH FROM d) IN (6,7,8)  THEN 'Summer'
    ELSE 'Autumn'
  END AS season_uk
FROM bounds b, generate_series(b.start_date, b.end_date, interval '1 day') AS g(d);

ALTER TABLE core.dim_calendar ADD PRIMARY KEY(date);

-- 3) Product Dimension (valid price only)
DROP TABLE IF EXISTS core.dim_product;
CREATE TABLE core.dim_product AS
SELECT
  p.product_id,
  p.product_name,
  p.product_category,
  p.selling_price
FROM stg.stg_products p
WHERE p.product_id IS NOT NULL
  AND p.selling_price IS NOT NULL
  AND p.selling_price > 0;

ALTER TABLE core.dim_product ADD PRIMARY KEY (product_id);
CREATE INDEX IF NOT EXISTS idx_dim_product_category ON core.dim_product(product_category);

-- 4) Customer Dimension (first_seen across ALL purchases)
DROP TABLE IF EXISTS core.dim_customer;
CREATE TABLE core.dim_customer AS
WITH first_seen AS (
  SELECT
    o.user_id AS customer_id,
    MIN(o.event_date) AS first_seen_date
  FROM stg.stg_orders o
  WHERE o.interaction_type = 'purchase'
  GROUP BY o.user_id
)
SELECT
  c.customer_id,
  c.gender,
  c.location,
  COALESCE(r.region, 'Unknown') AS region,
  c.payment_method,
  c.subscription_status,
  fs.first_seen_date
FROM stg.stg_customers c
LEFT JOIN core.dim_region r ON r.state_name = c.location
LEFT JOIN first_seen fs     ON fs.customer_id = c.customer_id
WHERE c.customer_id IS NOT NULL;

ALTER TABLE core.dim_customer ADD PRIMARY KEY (customer_id);
CREATE INDEX IF NOT EXISTS idx_dim_customer_region  ON core.dim_customer(region);
CREATE INDEX IF NOT EXISTS idx_dim_customer_payment ON core.dim_customer(payment_method);

-- 5) Quick counts
SELECT 'dim_region'   AS t, COUNT(*) FROM core.dim_region
UNION ALL
SELECT 'dim_calendar', COUNT(*) FROM core.dim_calendar
UNION ALL
SELECT 'dim_product', COUNT(*) FROM core.dim_product
UNION ALL
SELECT 'dim_customer',COUNT(*) FROM core.dim_customer;
