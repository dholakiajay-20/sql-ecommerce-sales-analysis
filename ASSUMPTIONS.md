# ASSUMPTIONS.md

Project: SQL – E-commerce Sales Data 2024

## Scope & Time
- Analysis window: 2024-01-01 to 2024-12-31 (inclusive) based on event_ts (orders).
- Timezone: Europe/London. Timestamps normalized to ISO-8601.
- Currency: USD (prices come with "$"). No FX conversion.

## Entity & Keys
- Customers: `customer_details.csv` primary key = `Customer ID` (canonical: customer_id).
- Products: `product_details.csv` primary key = `Uniqe Id` (canonical: product_id).
- Orders: `orders_2024.csv` has no order_id; surrogate `order_id` generated as hash(user_id, product_id, event_ts) for purchase events.
- Join keys:
  - orders.user_id ↔ customers.customer_id (cast to INT; drop if no match).
  - orders.product_id ↔ products.product_id (string; drop if no match).

## Events & Sales Logic
- Only `Interaction type = 'purchase'` is revenue; `view/like` excluded from sales KPIs (kept in staging for potential funnel analysis).
- Quantity not provided in orders → assume `quantity = 1` per purchase line.
- Price source = products.selling_price (parsed numeric from "$xx.xx"); if missing, drop the line from revenue KPIs (log as data issue).
- Discounts/tax/shipping not present → assumed `0`.
- Returns/cancellations not present → assumed `0`; return-rate KPIs omitted.

## Customer Attributes
- Payment method sourced from `Payment Method` in customers; treated as the customer’s typical method for 2024 purchases (ack: imperfect).
- Location is a free-text US state or region string (e.g., “Kentucky”). Regional roll-up uses US Census Regions:
  - West, Midwest, South, Northeast. Unknown → “Unknown”.

## Products & Categories
- Use `Category` from products as `product_category`. If pipe-delimited (e.g. “Sports & Outdoors | Longboards”), use the leftmost segment as canonical category; remainder ignored.
- Missing or blank category → “Other”.

## Data Quality Rules (enforced during cleaning)
- IDs must be non-null and unique at their grain (customer_id, product_id, order_id).
- Non-negative numeric fields (price ≥ 0).
- Valid domain values for `interaction_type ∈ {purchase, view, like}`.
- Email/phone not available; no dedup beyond exact customer_id.
- Orphan orders (no customer/product match) removed from fact; counted in DQ report.

## Metrics & Definitions
- gross_item_value = quantity * unit_price
- net_revenue = gross_item_value (since discounts/tax/shipping = 0)
- cogs = NULL (not provided) → margin KPIs omitted unless a % assumption is later added.
- AOV = net_revenue / distinct orders
- LTV (2024 simple) = Σ net_revenue per customer (revenue-only version)
- Repeat rate = % of customers with ≥2 purchases in 2024
- Season (UK): Winter (Dec–Feb), Spring (Mar–May), Summer (Jun–Aug), Autumn (Sep–Nov)

## Limitations
- No quantities, costs, returns; margins and units are proxied (qty=1) and COGS unavailable.
- Payment method at customer-level may not reflect per-order reality.
- Free-text locations can be messy; unmatched → “Unknown”.

## Change Log
- v1.0 — Initial assumptions for cleaning/modeling. Update if schema or data change.
