/*
 * Step 2: Product dimension — pruned product catalog
 * Source: bigquery-public-data.thelook_ecommerce.products
 */
SELECT
  id AS product_id,
  name        AS product_name,
  department,
  category,
  brand,
  cost,
  retail_price
FROM `bigquery-public-data.thelook_ecommerce.products`
