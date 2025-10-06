-- FILE: sql/01_schema_and_load.sql
-- WHY: Deterministic RAW load using absolute container paths to avoid Windows/psql var issues.

\set ON_ERROR_STOP on

-- Schemas
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS core;
SET search_path = raw, stg, core, public;

-- ---------- RAW: CUSTOMERS ----------
DROP TABLE IF EXISTS raw.customers_raw;
CREATE TABLE raw.customers_raw (
  "Customer ID" TEXT,
  "Age" TEXT,
  "Gender" TEXT,
  "Item Purchased" TEXT,
  "Category" TEXT,
  "Purchase Amount (USD)" TEXT,
  "Location" TEXT,
  "Size" TEXT,
  "Color" TEXT,
  "Season" TEXT,
  "Review Rating" TEXT,
  "Subscription Status" TEXT,
  "Shipping Type" TEXT,
  "Discount Applied" TEXT,
  "Promo Code Used" TEXT,
  "Previous Purchases" TEXT,
  "Payment Method" TEXT,
  "Frequency of Purchases" TEXT
);

\copy raw.customers_raw FROM '/data/customer_details.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- ---------- RAW: PRODUCTS ----------
DROP TABLE IF EXISTS raw.products_raw;
CREATE TABLE raw.products_raw (
  "Uniqe Id" TEXT,
  "Product Name" TEXT,
  "Brand Name" TEXT,
  "Asin" TEXT,
  "Category" TEXT,
  "Upc Ean Code" TEXT,
  "List Price" TEXT,
  "Selling Price" TEXT,
  "Quantity" TEXT,
  "Model Number" TEXT,
  "About Product" TEXT,
  "Product Specification" TEXT,
  "Technical Details" TEXT,
  "Shipping Weight" TEXT,
  "Product Dimensions" TEXT,
  "Image" TEXT,
  "Variants" TEXT,
  "Sku" TEXT,
  "Product Url" TEXT,
  "Stock" TEXT,
  "Product Details" TEXT,
  "Dimensions" TEXT,
  "Color" TEXT,
  "Ingredients" TEXT,
  "Direction To Use" TEXT,
  "Is Amazon Seller" TEXT,
  "Size Quantity Variant" TEXT,
  "Product Description" TEXT
);

\copy raw.products_raw FROM '/data/product_details.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- ---------- RAW: ORDERS ----------
DROP TABLE IF EXISTS raw.orders_raw;
CREATE TABLE raw.orders_raw (
  "user id" TEXT,
  "product id" TEXT,
  "Interaction type" TEXT,
  "Time stamp" TEXT,
  "Unnamed: 4" TEXT
);

\copy raw.orders_raw FROM '/data/orders_2024.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- ---------- Sanity counts ----------
SELECT 'customers_raw' AS table_name, COUNT(*) AS rows FROM raw.customers_raw
UNION ALL
SELECT 'products_raw', COUNT(*) FROM raw.products_raw
UNION ALL
SELECT 'orders_raw', COUNT(*) FROM raw.orders_raw
;
