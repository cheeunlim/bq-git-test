/*
 * Step 3: Revenue & Margin KPI table
 * Grain: (order_month, department, category)
 * Depends on: stg_filtered_order_items, stg_product_dim
 *
 * Computes monthly order volume, active customers, return rates,
 * net revenue, gross margin, and MoM net revenue growth.
 */
WITH
  monthly_category_metrics AS (
    SELECT
      oi.order_month,
      p.department,
      p.category,
      COUNT(DISTINCT oi.order_id)                                        AS total_orders,
      COUNT(DISTINCT oi.user_id)                                         AS active_customers,
      COUNT(oi.order_item_id)                                            AS total_items_sold,
      COUNTIF(oi.status = 'Returned')                                    AS returned_items,
      ROUND(SUM(oi.sale_price), 2)                                       AS gross_revenue,
      ROUND(SUM(IF(oi.status != 'Returned', oi.sale_price, 0)), 2)       AS net_revenue,
      ROUND(SUM(IF(oi.status != 'Returned', oi.sale_price - p.cost, 0)), 2) AS net_gross_margin
    FROM ${ref("stg_filtered_order_items")} AS oi
    INNER JOIN ${ref("stg_product_dim")} AS p
      ON oi.product_id = p.product_id
    GROUP BY
      oi.order_month,
      p.department,
      p.category
  ),

  with_prior_month AS (
    SELECT
      *,
      LAG(net_revenue) OVER (
        PARTITION BY department, category
        ORDER BY order_month
      ) AS prev_month_net_revenue
    FROM monthly_category_metrics
  )

SELECT
  order_month,
  department,
  category,
  total_orders,
  active_customers,
  total_items_sold,
  returned_items,
  ROUND(SAFE_DIVIDE(returned_items, total_items_sold) * 100, 2)                       AS item_return_rate_pct,
  gross_revenue,
  net_revenue,
  net_gross_margin,
  ROUND(SAFE_DIVIDE(net_gross_margin, net_revenue) * 100, 2)                          AS gross_margin_pct,
  ROUND(SAFE_DIVIDE(net_revenue - prev_month_net_revenue, prev_month_net_revenue) * 100, 2) AS mom_net_revenue_growth_pct
FROM with_prior_month
ORDER BY
  order_month DESC,
  net_revenue DESC
