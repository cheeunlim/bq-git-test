/*
 * Data quality assertion: verify no negative net revenue rows exist
 * in the KPI table. If this query returns any rows, the assertion fails.
 * Depends on: thelook_revenue_margin_kpi
 */
SELECT *
FROM thelook_revenue_margin_kpi
WHERE net_revenue < 0
