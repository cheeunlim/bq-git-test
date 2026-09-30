/*
 * =============================================================================
 * Pipeline:    thelook_revenue_margin_kpi
 * Target Grain: (order_month, department, category)
 * Source:      `bigquery-public-data.thelook_ecommerce`
 * Description: Production reporting query computing monthly order volume,
 *              active customers, return rates, net revenue, realized gross
 *              margin, and month-over-month (MoM) net revenue growth across
 *              completed calendar months.
 *
 * BigQuery SQL Optimizations Applied:
 *   1. Column Pruning: Selects only required columns from `order_items` and
 *      `products` in base CTEs.
 *   2. Predicate Pushdown: Filters out cancelled orders and restricts the
 *      timestamp window to completed months in the initial table scan.
 *   3. Early Aggregation: Aggregates item-level metrics prior to computing
 *      window functions and derived ratios.
 *   4. Common Subexpression Reuse: Factors out `prev_month_net_revenue` in a
 *      dedicated CTE to avoid duplicate `LAG()` window evaluations.
 * =============================================================================
 */

WITH
  -- 1. Base fact scan with column pruning and predicate pushdown
  filtered_order_items AS (
    SELECT
      id AS order_item_id,
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
      AND created_at < TIMESTAMP(DATE_TRUNC(CURRENT_DATE(), MONTH))
  ),

  -- 2. Pruned product dimension
  product_dim AS (
    SELECT
      id AS product_id,
      department,
      category,
      cost
    FROM `bigquery-public-data.thelook_ecommerce.products`
  ),

  -- 3. Early aggregation at the target (order_month, department, category) grain
  monthly_category_metrics AS (
    SELECT
      oi.order_month,
      p.department,
      p.category,
      COUNT(DISTINCT oi.order_id) AS total_orders,
      COUNT(DISTINCT oi.user_id) AS active_customers,
      COUNT(oi.order_item_id) AS total_items_sold,
      COUNTIF(oi.status = 'Returned') AS returned_items,
      ROUND(SUM(oi.sale_price), 2) AS gross_revenue,
      ROUND(SUM(IF(oi.status != 'Returned', oi.sale_price, 0)), 2) AS net_revenue,
      ROUND(SUM(IF(oi.status != 'Returned', oi.sale_price - p.cost, 0)), 2) AS net_gross_margin
    FROM filtered_order_items AS oi
    INNER JOIN product_dim AS p
      ON oi.product_id = p.product_id
    GROUP BY
      oi.order_month,
      p.department,
      p.category
  ),

  -- 4. Reuse window expression for prior-month net revenue comparison
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
  ROUND(SAFE_DIVIDE(returned_items, total_items_sold) * 100, 2) AS item_return_rate_pct,
  gross_revenue,
  net_revenue,
  net_gross_margin,
  ROUND(SAFE_DIVIDE(net_gross_margin, net_revenue) * 100, 2) AS gross_margin_pct,
  ROUND(
    SAFE_DIVIDE(net_revenue - prev_month_net_revenue, prev_month_net_revenue) * 100,
    2
  ) AS mom_net_revenue_growth_pct
FROM with_prior_month
ORDER BY
  order_month DESC,
  net_revenue DESC;
