-- FILE: sql/02_cleaning_rules.sql
-- WHY: Build typed/normalized STAGING tables; robust price parsing; safe drops for dependent view.

SET search_path = raw, stg, core, public;

-- =========================
-- A) CUSTOMERS → stg_customers
-- =========================
DROP TABLE IF EXISTS stg.stg_customers;
CREATE TABLE stg.stg_customers AS
WITH base AS (
  SELECT
    NULLIF(TRIM("Customer ID"), '') AS customer_id_txt,
    NULLIF(TRIM("Age"), '') AS age_txt,
    NULLIF(LOWER(TRIM("Gender")), '') AS gender_raw,
    INITCAP(NULLIF(TRIM("Location"), '')) AS location_clean,
    NULLIF(LOWER(TRIM("Payment Method")), '') AS payment_raw,
    NULLIF(LOWER(TRIM("Subscription Status")), '') AS sub_raw,
    NULLIF(TRIM("Previous Purchases"), '') AS prev_purch_txt
  FROM raw.customers_raw
),
typed AS (
  SELECT
    CASE WHEN customer_id_txt ~ '^\d+$' THEN customer_id_txt::INT END AS customer_id,
    CASE WHEN age_txt ~ '^\d+$' THEN age_txt::INT END AS age,
    gender_raw,
    location_clean,
    payment_raw,
    sub_raw,
    CASE WHEN prev_purch_txt ~ '^\d+$' THEN prev_purch_txt::INT END AS previous_purchases
  FROM base
),
normalized AS (
  SELECT
    customer_id,
    CASE WHEN age BETWEEN 13 AND 100 THEN age END AS age,
    CASE
      WHEN gender_raw LIKE 'm%' THEN 'male'
      WHEN gender_raw LIKE 'f%' THEN 'female'
      WHEN gender_raw IS NULL OR gender_raw IN ('', 'na', 'n/a', 'unknown') THEN 'unknown'
      ELSE 'other'
    END AS gender,
    COALESCE(NULLIF(location_clean,''),'Unknown') AS location,
    CASE
      WHEN payment_raw LIKE '%credit%' THEN 'credit_card'
      WHEN payment_raw LIKE '%debit%'  THEN 'debit_card'
      WHEN payment_raw LIKE '%paypal%' THEN 'paypal'
      WHEN payment_raw LIKE '%bank%'   THEN 'bank_transfer'
      WHEN payment_raw LIKE '%venmo%'  THEN 'venmo'
      WHEN payment_raw LIKE '%cash%'   THEN 'cash'
      WHEN payment_raw IS NULL OR payment_raw='' THEN 'other'
      ELSE 'other'
    END AS payment_method,
    CASE
      WHEN sub_raw IN ('yes','y','true','1') THEN 'yes'
      WHEN sub_raw IN ('no','n','false','0') THEN 'no'
      ELSE NULL
    END AS subscription_status,
    previous_purchases
  FROM typed
)
SELECT *
FROM normalized
WHERE customer_id IS NOT NULL
;

-- quick visibility
SELECT COUNT(*) FROM stg.stg_customers;

-- =========================
-- B) PRODUCTS → stg_products
-- (fix: extract FIRST price token; ignore junk like "74.99249.99")
-- =========================
DROP TABLE IF EXISTS stg.stg_products;

CREATE TABLE stg.stg_products AS
WITH base AS (
  SELECT
    NULLIF(TRIM("Uniqe Id"), '') AS product_id,
    NULLIF(TRIM("Product Name"), '') AS product_name,
    NULLIF(TRIM("Category"), '') AS product_category_raw,
    NULLIF(TRIM("Selling Price"), '') AS selling_price_raw,
    NULLIF(TRIM("Brand Name"), '') AS brand_name,
    NULLIF(TRIM("Model Number"), '') AS model_number,
    NULLIF(TRIM("Image"), '') AS image_url,
    NULLIF(TRIM("Product Url"), '') AS product_url,
    NULLIF(UPPER(TRIM("Is Amazon Seller")), '') AS is_amazon_seller_raw
  FROM raw.products_raw
),
-- WHY: Pull only the first number-like token (supports $ and commas).
price_extracted AS (
  SELECT
    product_id,
    product_name,
    product_category_raw,
    selling_price_raw,
    brand_name,
    model_number,
    image_url,
    product_url,
    is_amazon_seller_raw,
    -- first match like $1,234.56 or 1234.56
    substring(
      selling_price_raw
      from '\$?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)'
    ) AS price_token
  FROM base
),
parsed AS (
  SELECT
    product_id,
    product_name,
    COALESCE(
      NULLIF(TRIM(SPLIT_PART(REPLACE(product_category_raw, '>', '|'), '|', 1)), ''),
      'Other'
    ) AS product_category,
    CASE
      WHEN price_token IS NULL THEN NULL
      ELSE NULLIF(REPLACE(price_token, ',', ''), '')::NUMERIC(10,2)
    END AS selling_price,
    brand_name,
    model_number,
    image_url,
    product_url,
    CASE
      WHEN is_amazon_seller_raw IN ('Y','YES','TRUE','1') THEN 'Y'
      WHEN is_amazon_seller_raw IN ('N','NO','FALSE','0')  THEN 'N'
      ELSE NULL
    END AS is_amazon_seller
  FROM price_extracted
)
SELECT *
FROM parsed
WHERE product_id IS NOT NULL
;

-- =========================
-- C) ORDERS → stg_orders
-- (fix: drop dependent view first, then table)
-- =========================
DROP VIEW  IF EXISTS stg.v_stg_orders_2024;
DROP TABLE IF EXISTS stg.stg_orders;

CREATE TABLE stg.stg_orders AS
WITH base AS (
  SELECT
    NULLIF(TRIM("user id"), '') AS user_id_txt,
    NULLIF(TRIM("product id"), '') AS product_id,
    LOWER(NULLIF(TRIM("Interaction type"), '')) AS interaction_type_raw,
    NULLIF(TRIM("Time stamp"), '') AS event_ts_raw
  FROM raw.orders_raw
),
typed AS (
  SELECT
    CASE WHEN user_id_txt ~ '^\d+$' THEN user_id_txt::INT END AS user_id,
    product_id,
    CASE
      WHEN interaction_type_raw IN ('purchase','view','like') THEN interaction_type_raw
      ELSE NULL
    END AS interaction_type,
    (to_timestamp(event_ts_raw, 'DD/MM/YYYY HH24:MI') AT TIME ZONE 'Europe/London')::timestamptz AS event_ts
  FROM base
)
SELECT
  user_id,
  product_id,
  interaction_type,
  event_ts,
  (event_ts AT TIME ZONE 'Europe/London')::date AS event_date,
  CASE WHEN date_part('year', event_ts) = 2024 THEN 1 ELSE 0 END AS in_2024
FROM typed
WHERE user_id IS NOT NULL
  AND product_id IS NOT NULL
  AND interaction_type IS NOT NULL
  AND event_ts IS NOT NULL
;

-- limit-to-2024 view
CREATE VIEW stg.v_stg_orders_2024 AS
SELECT * FROM stg.stg_orders WHERE in_2024 = 1;

-- =========================
-- D) DQ HELPER TABLES
-- =========================
DROP TABLE IF EXISTS stg.stg_dq_invalid_price;
CREATE TABLE stg.stg_dq_invalid_price AS
SELECT p.*
FROM stg.stg_products p
WHERE p.selling_price IS NULL
   OR p.selling_price <= 0;

DROP TABLE IF EXISTS stg.stg_dq_orphans_products;
CREATE TABLE stg.stg_dq_orphans_products AS
SELECT o.*
FROM stg.v_stg_orders_2024 o
LEFT JOIN stg.stg_products p ON p.product_id = o.product_id
WHERE o.interaction_type = 'purchase'
  AND p.product_id IS NULL;

DROP TABLE IF EXISTS stg.stg_dq_orphans_customers;
CREATE TABLE stg.stg_dq_orphans_customers AS
SELECT o.*
FROM stg.v_stg_orders_2024 o
LEFT JOIN stg.stg_customers c ON c.customer_id = o.user_id
WHERE o.interaction_type = 'purchase'
  AND c.customer_id IS NULL;

-- =========================
-- E) Quick counts
-- =========================
SELECT 'stg_customers' AS t, COUNT(*) FROM stg.stg_customers
UNION ALL SELECT 'stg_products', COUNT(*) FROM stg.stg_products
UNION ALL SELECT 'stg_orders', COUNT(*) FROM stg.stg_orders
UNION ALL SELECT 'dq_invalid_price', COUNT(*) FROM stg.stg_dq_invalid_price
UNION ALL SELECT 'dq_orphans_products', COUNT(*) FROM stg.stg_dq_orphans_products
UNION ALL SELECT 'dq_orphans_customers', COUNT(*) FROM stg.stg_dq_orphans_customers
;
