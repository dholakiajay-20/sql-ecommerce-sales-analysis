# SCHEMA_SPEC.md
Project: SQL – E-commerce Analytics 2024  
Layered model: **raw → stg → core (dims + fact)**

## 0) Conventions
- Schemas: `raw`, `stg`, `core`
- Case: snake_case for columns; singular table names in dims.
- Timezone: Europe/London; dates ISO-8601.
- Currency: USD.
- Types (canonical → engine):
  - **INT** → INTEGER (PG/SQLite), INT (MySQL)
  - **NUMERIC(10,2)** → NUMERIC(10,2) (PG), DECIMAL(10,2) (MySQL), REAL (SQLite)
  - **TEXT** → TEXT (PG/SQLite), VARCHAR (MySQL)
  - **TIMESTAMPTZ** → TIMESTAMP WITH TIME ZONE (PG), DATETIME (MySQL), TEXT ISO (SQLite)

---

## 1) RAW LAYER (land as-is; minimal typing)
### raw.customers_raw  (from `data/customer_details.csv`)
| Column (raw) | Canonical | Type | Notes |
|---|---|---|---|
| Customer ID | customer_id | TEXT | keep raw; cast later |
| Age | age | TEXT | |
| Gender | gender | TEXT | |
| Item Purchased | item_purchased | TEXT | |
| Category | customer_category | TEXT | |
| Purchase Amount (USD) | purchase_amount_usd | TEXT | |
| Location | location | TEXT | |
| Size | size | TEXT | |
| Color | color | TEXT | |
| Season | season | TEXT | |
| Review Rating | review_rating | TEXT | |
| Subscription Status | subscription_status | TEXT | |
| Shipping Type | shipping_type | TEXT | |
| Discount Applied | discount_applied | TEXT | |
| Promo Code Used | promo_code_used | TEXT | |
| Previous Purchases | previous_purchases | TEXT | |
| Payment Method | payment_method | TEXT | |
| Frequency of Purchases | purchase_frequency | TEXT | |

### raw.products_raw (from `data/product_details.csv`)
| Raw | Canonical | Type | Notes |
|---|---|---|---|
| Uniqe Id | product_id | TEXT | key |
| Product Name | product_name | TEXT | |
| Brand Name | brand_name | TEXT | mostly null |
| Category | product_category_raw | TEXT | may be pipe-delimited |
| Selling Price | selling_price_raw | TEXT | "$xx.xx" |
| Model Number | model_number | TEXT | |
| About Product | about_product | TEXT | |
| Product Specification | product_specification | TEXT | |
| Technical Details | technical_details | TEXT | |
| Shipping Weight | shipping_weight_raw | TEXT | free text |
| Product Dimensions | product_dimensions_raw | TEXT | |
| Image | image_url | TEXT | |
| Variants | variants | TEXT | |
| Product Url | product_url | TEXT | |
| Is Amazon Seller | is_amazon_seller | TEXT | |
| (others 100% null) | (ignored) |  | dropped later |

### raw.orders_raw (from `data/orders_2024.csv`)
| Raw | Canonical | Type | Notes |
|---|---|---|---|
| user id | user_id_raw | TEXT | cast later |
| product id | product_id_raw | TEXT | |
| Interaction type | interaction_type_raw | TEXT | purchase/view/like |
| Time stamp | event_ts_raw | TEXT | "DD/MM/YYYY H:MM" |
| Unnamed: 4 | drop_col | TEXT | empty |

---

## 2) STAGING LAYER (typed, cleaned, normalized)
### stg_customers
| Column | Type | Null | Rule |
|---|---|---:|---|
| customer_id | INT | NO | cast; drop non-numeric |
| age | INT | YES | clamp 13–100; else null |
| gender | TEXT | YES | normalize {male,female,other,unknown} |
| location | TEXT | YES | trim; title case |
| payment_method | TEXT | YES | map to {credit_card,debit_card,paypal,bank_transfer,cash,venmo,other} |
| subscription_status | TEXT | YES | {yes,no} |
| purchase_frequency | TEXT | YES | bucket later |
| previous_purchases | INT | YES | cast |
| ...(retain minimal attributes useful for dims) |  |  |  |

> Non-customer fields (e.g., item_purchased, purchase_amount_usd) are **ignored** in customer dim.

### stg_products
| Column | Type | Null | Rule |
|---|---|---:|---|
| product_id | TEXT | NO | from raw |
| product_name | TEXT | NO | trim |
| product_category | TEXT | YES | leftmost segment of `product_category_raw` split by '|' or '>' |
| selling_price | NUMERIC(10,2) | YES | parse from `$`; invalid → null |
| brand_name | TEXT | YES | |
| model_number | TEXT | YES | |
| image_url | TEXT | YES | |
| product_url | TEXT | YES | |
| is_amazon_seller | TEXT | YES | {Y,N} normalized |

### stg_orders
| Column | Type | Null | Rule |
|---|---|---:|---|
| user_id | INT | NO | cast from user_id_raw |
| product_id | TEXT | NO | from product_id_raw |
| interaction_type | TEXT | NO | normalize → {purchase,view,like}; others → drop |
| event_ts | TIMESTAMPTZ | NO | parse DD/MM/YYYY H:MM; set TZ Europe/London |
| event_date | DATE | NO | derived from event_ts |
| in_2024 | INT | NO | 1 if date ∈ 2024; else 0 |

> Keep only in_2024=1 for sales. Drop empty column.

### Staging DQ outputs (optional helper tables)
- `stg_dq_orphans_customers` (orders with missing customer)
- `stg_dq_orphans_products` (orders with missing product)
- `stg_dq_invalid_price` (products with null/negative price)

---

## 3) CORE DIMENSIONS
### core.dim_customer
| Column | Type | PK | Notes |
|---|---|:--:|---|
| customer_id | INT | ✅ | |
| gender | TEXT |  | normalized |
| location | TEXT |  | raw state/city string |
| region | TEXT |  | mapped via dim_region (West/Midwest/South/Northeast/Unknown) |
| payment_method | TEXT |  | typical method from stg_customers |
| subscription_status | TEXT |  | |
| first_seen_date | DATE |  | min purchase date in 2024 if available |

### core.dim_product
| Column | Type | PK | Notes |
|---|---|:--:|---|
| product_id | TEXT | ✅ | |
| product_name | TEXT |  | |
| product_category | TEXT |  | |
| selling_price | NUMERIC(10,2) |  | latest/only price from stg_products |

### core.dim_calendar (2024 date spine)
| Column | Type | Notes |
|---|---|---|
| date | DATE | PK |
| year | INT | 2024 only |
| month | INT | 1–12 |
| month_name | TEXT | Jan–Dec |
| quarter | INT | 1–4 |
| week_of_year | INT | ISO 1–53 |
| season_uk | TEXT | Winter/Spring/Summer/Autumn |

### core.dim_region (US state → region)
| State → Region mapping |
- **Northeast:** CT, ME, MA, NH, RI, VT, NJ, NY, PA  
- **Midwest:** IL, IN, MI, OH, WI, IA, KS, MN, MO, NE, ND, SD  
- **South:** DE, FL, GA, MD, NC, SC, VA, DC, WV, AL, KY, MS, TN, AR, LA, OK, TX  
- **West:** AZ, CO, ID, MT, NV, NM, UT, WY, AK, CA, HI, OR, WA  
- Anything else → `Unknown`.

---

## 4) CORE FACT
### core.fact_sales  (grain: **1 row per purchase event**)
| Column | Type | Null | Source/Rule |
|---|---|---:|---|
| order_id | TEXT | NO | hash(user_id, product_id, event_ts) |
| order_date | DATE | NO | from event_ts |
| customer_id | INT | NO | from stg_orders |
| product_id | TEXT | NO | from stg_orders |
| quantity | INT | NO | default 1 (assumption) |
| unit_price | NUMERIC(10,2) | NO | from dim_product.selling_price; if null → drop row & log |
| gross_item_value | NUMERIC(10,2) | NO | quantity * unit_price |
| discount_amount | NUMERIC(10,2) | NO | 0 (assumption) |
| tax_amount | NUMERIC(10,2) | NO | 0 (assumption) |
| shipping_fee | NUMERIC(10,2) | NO | 0 (assumption) |
| net_revenue | NUMERIC(10,2) | NO | gross_item_value - discount + tax + shipping |
| region | TEXT | YES | from dim_customer |
| payment_method | TEXT | YES | from dim_customer |
| created_at | TIMESTAMPTZ | NO | load timestamp |

**Exclusions:** interaction_type ≠ 'purchase', price null/≤0, missing product/customer keys.

---

## 5) Keys, Constraints, Indexes (performance-first)
- **PKs:**  
  - dim_customer(customer_id)  
  - dim_product(product_id)  
  - dim_calendar(date)  
  - fact_sales(order_id)
- **FKs:** (soft/optional in dev; enforce in prod)  
  - fact_sales.customer_id → dim_customer.customer_id  
  - fact_sales.product_id → dim_product.product_id  
  - fact_sales.order_date → dim_calendar.date
- **Indexes (non-unique):**  
  - fact_sales(order_date) – seasonality  
  - fact_sales(product_id) – category joins  
  - fact_sales(customer_id) – LTV/retention  
  - dim_product(product_category) – category analysis  
  - dim_customer(region, payment_method) – mix splits

---

## 6) Build/Load Order (deterministic)
1) Load raw: `customers_raw`, `products_raw`, `orders_raw`.  
2) Build staging: `stg_customers`, `stg_products`, `stg_orders` (+ DQ helper tables).  
3) Build dims: `dim_calendar` (2024), `dim_region` (static), `dim_customer`, `dim_product`.  
4) Build fact: `fact_sales` (purchases only).  
5) Create KPI views (next step).  
6) Run DQ checks; export summary.

---

## 7) DQ Acceptance (must pass or be disclosed)
- Unique keys on all dims; no null keys in fact.  
- Prices parsed and non-negative.  
- All fact rows dated in 2024.  
- Orphans logged = 0 (or reported in DQ summary with counts & examples).  

