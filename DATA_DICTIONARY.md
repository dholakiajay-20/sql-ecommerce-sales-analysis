# docs/DATA_DICTIONARY.md

# DATA_DICTIONARY.md
Project: SQL – E-commerce Sales Data 2024  
Baseline mapping from the provided CSVs. Types/null % are inferred from the raw files; final DB types may differ after cleaning.

## customers (customer_details.csv)
| Column | Inferred Type | Null % | Example Values |
|---|---|---:|---|
| Customer ID | int64 | 0.00% | 1, 2, 3, 4, 5 |
| Age | int64 | 0.00% | 55, 19, 50, 21, 45 |
| Gender | object | 0.00% | Male, Female |
| Item Purchased | object | 0.00% | Blouse, Sweater, Jeans, Sandals, Sneakers |
| Category | object | 0.00% | Clothing, Footwear, Outerwear, Accessories |
| Purchase Amount (USD) | int64 | 0.00% | 53, 64, 73, 90, 49 |
| Location | object | 0.00% | Kentucky, Maine, Massachusetts, Rhode Island, Oregon |
| Size | object | 0.00% | L, S, M, XL |
| Color | object | 0.00% | Gray, Maroon, Turquoise, White, Charcoal |
| Season | object | 0.00% | Winter, Spring, Summer, Fall |
| Review Rating | float64 | 0.00% | 3.1, 3.5, 2.7, 2.9, 3.2 |
| Subscription Status | object | 0.00% | Yes, No |
| Shipping Type | object | 0.00% | Express, Free Shipping, Next Day Air, Standard, 2-Day Shipping |
| Discount Applied | object | 0.00% | Yes, No |
| Promo Code Used | object | 0.00% | Yes, No |
| Previous Purchases | int64 | 0.00% | 14, 2, 23, 49, 31 |
| Payment Method | object | 0.00% | Venmo, Cash, Credit Card, PayPal, Bank Transfer, Debit Card |
| Frequency of Purchases | object | 0.00% | Fortnightly, Weekly, Annually, Quarterly, Bi-Weekly, Monthly, Every 3 Months |

## orders (orders_2024.csv)
| Column | Inferred Type | Null % | Example Values |
|---|---|---:|---|
| user id | float64 | 8.96% | 1.0, 2.0, 3.0, 4.0, 5.0 |
| product id | object | 8.96% | 4c69b61db1fc16e7013b43fc926e502d, …, e04b990e95bf73bbe6a3fa09785d7cd0 |
| Interaction type | object | 12.84% | purchase, view, like |
| Time stamp | object | 8.96% | 10/10/2023 8:00, 11/10/2023 8:00, 12/10/2023 8:00 |
| Unnamed: 4 | float64 | 100.00% |  |

> Note: Only **purchase** rows represent sales; others are behavioral signals.

## products (product_details.csv)
| Column | Inferred Type | Null % | Example Values |
|---|---|---:|---|
| Uniqe Id | object | 0.00% | 4c69b61db1fc16e7013b43fc926e502d, … |
| Product Name | object | 0.00% | DB Longboards CoreFlex…, Science Kit…, Collage 500 pc Puzzle |
| Brand Name | float64 | 100.00% |  |
| Asin | float64 | 100.00% |  |
| Category | object | 8.30% | Sports & Outdoors \| …, Toys & Games \| …, Home & Kitchen \| … |
| Upc Ean Code | object | 99.66% | 071444764117, 735533033354, 843905076882 |
| List Price | float64 | 100.00% |  |
| Selling Price | object | 1.07% | $237.68, $99.95, $34.99 |
| Quantity | float64 | 100.00% |  |
| Model Number | object | 17.70% | 55324, 142, 62151, AN4054Z |
| About Product | object | 2.73% | Marketing copy/snippets |
| Product Specification | object | 16.32% | Mixed key:value strings |
| Technical Details | object | 7.90% | Mixed technical text |
| Shipping Weight | object | 11.38% | 10.7 pounds, 4 pounds, 12.8 ounces |
| Product Dimensions | object | 95.21% | “14.7 x 11.1 x 10.2 inches”, … |
| Image | object | 0.00% | https://…/image.jpg |
| Variants | object | 75.22% | URLs / options |
| Sku | float64 | 100.00% |  |
| Product Url | object | 0.00% | https://www.amazon.com/… |
| Stock | float64 | 100.00% |  |
| Product Details | float64 | 100.00% |  |
| Dimensions | float64 | 100.00% |  |
| Color | float64 | 100.00% |  |
| Ingredients | float64 | 100.00% |  |
| Direction To Use | float64 | 100.00% |  |
| Is Amazon Seller | object | 0.00% | Y, N |
| Size Quantity Variant | float64 | 100.00% |  |
| Product Description | float64 | 100.00% |  |

## Canonical Naming (to use in SQL schema)
| Raw Column | Canonical Name |
|---|---|
| Customer ID | customer_id |
| Age | age |
| Gender | gender |
| Item Purchased | item_purchased |
| Category | customer_category |
| Purchase Amount (USD) | purchase_amount_usd |
| Location | location |
| Size | size |
| Color | color |
| Season | season |
| Review Rating | review_rating |
| Subscription Status | subscription_status |
| Shipping Type | shipping_type |
| Discount Applied | discount_applied |
| Promo Code Used | promo_code_used |
| Previous Purchases | previous_purchases |
| Payment Method | payment_method |
| Frequency of Purchases | purchase_frequency |
| user id | user_id |
| product id | product_id |
| Interaction type | interaction_type |
| Time stamp | event_ts |
| Unnamed: 4 | drop_column |
| Uniqe Id | product_id |
| Product Name | product_name |
| Brand Name | brand_name |
| Asin | asin |
| Category | product_category |
| Upc Ean Code | upc_ean_code |
| List Price | list_price |
| Selling Price | selling_price |
| Quantity | catalog_quantity |
| Model Number | model_number |
| About Product | about_product |
| Product Specification | product_specification |
| Technical Details | technical_details |
| Shipping Weight | shipping_weight |
| Product Dimensions | product_dimensions |
| Image | image_url |
| Variants | variants |
| Sku | sku |
| Product Url | product_url |
| Stock | stock |
| Product Details | product_details |
| Dimensions | dimensions |
| Color | product_color |
| Ingredients | ingredients |
| Direction To Use | direction_to_use |
| Is Amazon Seller | is_amazon_seller |
| Size Quantity Variant | size_quantity_variant |
| Product Description | product_description |

## Derived Fields (for `fact_sales`)
| Field | Definition |
|---|---|
| order_id | Surrogate (e.g., hash of user_id + product_id + event_ts) for purchase events |
| order_date | DATE(event_ts) |
| unit_price | Parsed numeric from products.selling_price (USD) |
| quantity | Default 1 (orders file lacks qty) |
| gross_item_value | quantity * unit_price |
| discount_amount | 0 (no discount in orders); optional rule from `Discount Applied`/`Promo Code Used` |
| tax_amount | 0 (not present) |
| shipping_fee | 0 (not present) |
| net_revenue | gross_item_value - discount_amount + tax_amount + shipping_fee |
| cogs | NULL (no cost table) or % assumption |
| gross_profit | net_revenue - cogs |
| payment_method | From customers if available by user/customer link |
| region | From customers.location (normalized) |

## Data Quality Notes
- `orders_2024.csv`: interaction types include **view/like/purchase**. Only **purchase** → sales.  
- `orders_2024.csv → Unnamed: 4`: empty column → drop.  
- `product_details.csv`: prices are strings with `$`; parse to numeric. `List Price` mostly NULL.  
- `customer_details.csv`: customer attributes; not line-item sales.  
- Keys: `customer_id` (customers), `product_id` (products). Orders lack `order_id` → generate.  
- Timestamps format: `DD/MM/YYYY H:MM` (observed); normalize to ISO; set Europe/London timezone.
