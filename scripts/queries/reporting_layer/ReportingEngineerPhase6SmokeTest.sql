USE NordaTradeDB;
GO

/* =========================================
   REPORTING ENGINEER
   WEEK 3 - PHASE 6
   SMOKE TEST
   ========================================= */

SELECT 'vw_sales_executive_summary' AS view_name, COUNT(*) AS row_count
FROM dbo.vw_sales_executive_summary
UNION ALL
SELECT 'vw_customer_360', COUNT(*)
FROM dbo.vw_customer_360
UNION ALL
SELECT 'vw_product_performance', COUNT(*)
FROM dbo.vw_product_performance
UNION ALL
SELECT 'vw_rep_performance_scorecard', COUNT(*)
FROM dbo.vw_rep_performance_scorecard
UNION ALL
SELECT 'vw_monthly_trend', COUNT(*)
FROM dbo.vw_monthly_trend
UNION ALL
SELECT 'vw_returns_analysis', COUNT(*)
FROM dbo.vw_returns_analysis;
GO

SELECT TOP (10)
    period_start_date,
    country_name,
    region_name,
    total_revenue,
    gross_margin_percent,
    quota_attainment_percent
FROM dbo.vw_sales_executive_summary
ORDER BY period_start_date DESC, country_name, region_name;
GO

SELECT TOP (10)
    customer_code,
    customer_name,
    assigned_rep_name,
    lifetime_revenue,
    order_frequency_last_12_months,
    rfm_segment
FROM dbo.vw_customer_360
ORDER BY lifetime_revenue DESC, customer_code;
GO

SELECT TOP (10)
    product_sku,
    product_name,
    category_name,
    total_units_sold,
    net_revenue,
    category_revenue_rank
FROM dbo.vw_product_performance
ORDER BY net_revenue DESC, product_sku;
GO

SELECT TOP (10)
    employee_code,
    rep_name,
    region_name,
    quarter_to_date_actual_revenue,
    quarter_to_date_attainment_percent,
    quarter_rank_in_region
FROM dbo.vw_rep_performance_scorecard
ORDER BY quarter_rank_in_region, rep_name;
GO

SELECT TOP (10)
    period_start_date,
    country_name,
    net_revenue,
    order_volume,
    average_order_value,
    revenue_change_percent
FROM dbo.vw_monthly_trend
ORDER BY country_name, period_start_date DESC;
GO

SELECT TOP (10)
    period_start_date,
    country_name,
    category_name,
    return_reason,
    return_rate_percent,
    total_credit_note_value
FROM dbo.vw_returns_analysis
ORDER BY period_start_date DESC, total_credit_note_value DESC;
GO
