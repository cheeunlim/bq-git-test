/*
 * Step 1: Staging view — filtered order items (non-cancelled, last 24 months)
 * Source: bigquery-public-data.thelook_ecommerce.order_items
 */
SELECT
  id              AS order_item_id,
  order_id,
  user_id,
  product_id,
  status,
  DATE(TIMESTAMP_TRUNC(created_at, MONTH)) AS order_month,
  sale_price
FROM `bigquery-public-data.thelook_ecommerce.order_items`
WHERE
  status != 'Cancelled'
  AND created_at >= TIMESTAMP(DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 24 MONTH))
  AND created_at <  TIMESTAMP(DATE_TRUNC(CURRENT_DATE(), MONTH))
