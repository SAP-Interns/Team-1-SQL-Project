USE NordaTradeDB;
GO

/* =========================================
   REPORTING ENGINEER
   WEEK 3 - PHASE 6
   SIMPLIFIED REPORTING LAYER
   ========================================= */

/* =========================================
   TIER 1 - BASE VIEWS
   ========================================= */

/* Base view: clean sales line record */
CREATE OR ALTER VIEW dbo.vw_base_order_line_detail
AS
SELECT
    li.line_item_id,
    li.order_id,
    so.order_status,
    so.customer_id,
    cr.country_name AS customer_country_name,
    so.sales_rep_id,
    rr.country_name AS sales_country_name,
    rr.region_name AS sales_region_name,
    li.product_id,
    p.product_sku,
    p.product_name,
    cat.category_name,
    d.full_date AS order_date,
    d.year AS order_year,
    d.quarter AS order_quarter,
    d.month AS order_month,
    d.month_name AS order_month_name,
    li.quantity,
    li.net_amount,
    CAST(li.net_amount - li.quantity * ISNULL(p.unit_cost, 0) AS DECIMAL(18,2)) AS gross_profit
FROM dbo.fact_order_line_items AS li
JOIN dbo.fact_sales_orders AS so
    ON li.order_id = so.order_id
JOIN dbo.dim_customers AS c
    ON so.customer_id = c.customer_id
JOIN dbo.dim_regions AS cr
    ON c.region_id = cr.region_id
JOIN dbo.dim_sales_reps AS sr
    ON so.sales_rep_id = sr.sales_rep_id
JOIN dbo.dim_regions AS rr
    ON sr.region_id = rr.region_id
JOIN dbo.dim_products AS p
    ON li.product_id = p.product_id
JOIN dbo.dim_categories AS cat
    ON p.category_id = cat.category_id
JOIN dbo.dim_date AS d
    ON li.date_id = d.date_id;
GO

/* Base view: quota facts with geography and time */
CREATE OR ALTER VIEW dbo.vw_base_quota_detail
AS
SELECT
    q.sales_rep_id,
    rr.country_name AS sales_country_name,
    rr.region_name AS sales_region_name,
    d.full_date AS quota_date,
    d.year AS quota_year,
    d.quarter AS quota_quarter,
    d.month AS quota_month,
    d.month_name AS quota_month_name,
    q.quota_period,
    q.quota_amount
FROM dbo.fact_quotas AS q
JOIN dbo.dim_sales_reps AS sr
    ON q.sales_rep_id = sr.sales_rep_id
JOIN dbo.dim_regions AS rr
    ON sr.region_id = rr.region_id
JOIN dbo.dim_date AS d
    ON q.date_id = d.date_id;
GO

/* Base view: return facts with product and customer context */
CREATE OR ALTER VIEW dbo.vw_base_return_detail
AS
SELECT
    fr.line_item_id,
    fr.return_quantity,
    fr.credit_amount,
    fr.return_reason,
    d.full_date AS return_date,
    d.year AS return_year,
    d.month AS return_month,
    d.month_name AS return_month_name,
    b.order_date AS sale_date,
    b.order_year AS sale_year,
    b.order_month AS sale_month,
    b.order_month_name AS sale_month_name,
    b.order_status,
    b.customer_id,
    b.customer_country_name,
    b.product_id,
    b.category_name,
    b.quantity AS sold_quantity
FROM dbo.fact_returns AS fr
JOIN dbo.vw_base_order_line_detail AS b
    ON fr.line_item_id = b.line_item_id
JOIN dbo.dim_date AS d
    ON fr.date_id = d.date_id;
GO

/* =========================================
   TIER 2 - SUMMARY VIEWS
   ========================================= */

/* Summary view: executive KPIs by month and sales geography */
CREATE OR ALTER VIEW dbo.vw_summary_sales_executive
AS
WITH metrics AS (
    SELECT
        DATEFROMPARTS(b.order_year, b.order_month, 1) AS period_start_date,
        b.order_year AS calendar_year,
        b.order_quarter AS calendar_quarter,
        b.order_month AS calendar_month,
        b.order_month_name AS month_name,
        b.sales_country_name AS country_name,
        b.sales_region_name AS region_name,
        COUNT(DISTINCT b.order_id) AS order_count,
        SUM(b.net_amount) AS total_revenue,
        SUM(b.gross_profit) AS gross_profit,
        CAST(0 AS DECIMAL(18,2)) AS quota_amount
    FROM dbo.vw_base_order_line_detail AS b
    WHERE b.order_status <> 'Cancelled'
    GROUP BY
        DATEFROMPARTS(b.order_year, b.order_month, 1),
        b.order_year,
        b.order_quarter,
        b.order_month,
        b.order_month_name,
        b.sales_country_name,
        b.sales_region_name

    UNION ALL

    SELECT
        DATEFROMPARTS(q.quota_year, q.quota_month, 1),
        q.quota_year,
        q.quota_quarter,
        q.quota_month,
        q.quota_month_name,
        q.sales_country_name,
        q.sales_region_name,
        0,
        0.00,
        0.00,
        SUM(q.quota_amount)
    FROM dbo.vw_base_quota_detail AS q
    WHERE q.quota_period = 'Monthly'
    GROUP BY
        DATEFROMPARTS(q.quota_year, q.quota_month, 1),
        q.quota_year,
        q.quota_quarter,
        q.quota_month,
        q.quota_month_name,
        q.sales_country_name,
        q.sales_region_name
)
SELECT
    period_start_date,
    calendar_year,
    calendar_quarter,
    calendar_month,
    month_name,
    country_name,
    region_name,
    SUM(order_count) AS order_count,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS total_revenue,
    CAST(SUM(gross_profit) AS DECIMAL(18,2)) AS gross_profit,
    CAST(
        SUM(gross_profit) * 100.0 / NULLIF(SUM(total_revenue), 0)
        AS DECIMAL(18,2)
    ) AS gross_margin_percent,
    CAST(
        SUM(total_revenue) * 1.0 / NULLIF(SUM(order_count), 0)
        AS DECIMAL(18,2)
    ) AS average_order_value,
    CAST(SUM(quota_amount) AS DECIMAL(18,2)) AS quota_amount,
    CAST(
        SUM(total_revenue) * 100.0 / NULLIF(SUM(quota_amount), 0)
        AS DECIMAL(18,2)
    ) AS quota_attainment_percent
FROM metrics
GROUP BY
    period_start_date,
    calendar_year,
    calendar_quarter,
    calendar_month,
    month_name,
    country_name,
    region_name;
GO

/* Summary view: customer 360 with assigned rep and RFM segment */
CREATE OR ALTER VIEW dbo.vw_summary_customer_360
AS
WITH context AS (
    SELECT CAST(GETDATE() AS DATE) AS as_of_date
),
sales AS (
    SELECT
        b.customer_id,
        CAST(SUM(b.net_amount) AS DECIMAL(18,2)) AS lifetime_revenue,
        CAST(SUM(b.net_amount) * 1.0 / NULLIF(COUNT(DISTINCT b.order_id), 0) AS DECIMAL(18,2)) AS average_order_value,
        MAX(b.order_date) AS last_order_date,
        DATEDIFF(DAY, MAX(b.order_date), MAX(ctx.as_of_date)) AS days_since_last_order,
        SUM(b.quantity) AS units_sold,
        COUNT(DISTINCT CASE
            WHEN b.order_date >= DATEADD(YEAR, -1, ctx.as_of_date) THEN b.order_id
        END) AS order_frequency_last_12_months,
        CAST(SUM(CASE
            WHEN b.order_date >= DATEADD(YEAR, -1, ctx.as_of_date) THEN b.net_amount
            ELSE 0
        END) AS DECIMAL(18,2)) AS revenue_last_12_months
    FROM dbo.vw_base_order_line_detail AS b
    CROSS JOIN context AS ctx
    WHERE b.order_status <> 'Cancelled'
    GROUP BY
        b.customer_id
),
returns AS (
    SELECT
        r.customer_id,
        SUM(r.return_quantity) AS units_returned
    FROM dbo.vw_base_return_detail AS r
    WHERE r.order_status <> 'Cancelled'
    GROUP BY
        r.customer_id
)
SELECT
    c.customer_id,
    c.customer_code,
    c.customer_name,
    c.account_tier,
    ca.assigned_rep_name,
    ISNULL(s.lifetime_revenue, 0.00) AS lifetime_revenue,
    ISNULL(s.order_frequency_last_12_months, 0) AS order_frequency_last_12_months,
    s.last_order_date,
    ISNULL(s.average_order_value, 0.00) AS average_order_value,
    CAST(
        ISNULL(r.units_returned, 0) * 100.0
        / NULLIF(ISNULL(s.units_sold, 0), 0)
        AS DECIMAL(18,2)
    ) AS return_rate_percent,
    CASE
        WHEN s.last_order_date IS NULL THEN 'Lost'
        WHEN s.days_since_last_order <= 30
         AND ISNULL(s.order_frequency_last_12_months, 0) <= 2 THEN 'New'
        WHEN s.days_since_last_order <= 60
         AND ISNULL(s.order_frequency_last_12_months, 0) >= 12
         AND ISNULL(s.revenue_last_12_months, 0.00) >= 15000 THEN 'Champions'
        WHEN s.days_since_last_order <= 90
         AND ISNULL(s.order_frequency_last_12_months, 0) >= 8
         AND ISNULL(s.revenue_last_12_months, 0.00) >= 8000 THEN 'Loyal'
        WHEN s.days_since_last_order > 90
         AND (ISNULL(s.order_frequency_last_12_months, 0) >= 8 OR ISNULL(s.revenue_last_12_months, 0.00) >= 8000) THEN 'At Risk'
        ELSE 'Lost'
    END AS rfm_segment
FROM dbo.dim_customers AS c
CROSS JOIN context AS ctx
LEFT JOIN sales AS s
    ON c.customer_id = s.customer_id
LEFT JOIN returns AS r
    ON c.customer_id = r.customer_id
OUTER APPLY (
    SELECT TOP (1)
        sr.rep_name AS assigned_rep_name
    FROM dbo.rep_customer_assignments AS rca
    JOIN dbo.dim_sales_reps AS sr
        ON rca.sales_rep_id = sr.sales_rep_id
    WHERE rca.customer_id = c.customer_id
      AND rca.valid_from <= ctx.as_of_date
      AND (rca.valid_to IS NULL OR rca.valid_to >= ctx.as_of_date)
    ORDER BY
        CASE WHEN rca.is_active = 1 THEN 0 ELSE 1 END,
        rca.valid_from DESC,
        rca.assignment_id DESC
) AS ca;
GO

/* Summary view: product scorecard */
CREATE OR ALTER VIEW dbo.vw_summary_product_performance
AS
WITH sales AS (
    SELECT
        b.product_id,
        b.product_sku,
        b.product_name,
        b.category_name,
        SUM(b.quantity) AS total_units_sold,
        SUM(b.net_amount) AS net_revenue,
        SUM(b.gross_profit) AS gross_profit
    FROM dbo.vw_base_order_line_detail AS b
    WHERE b.order_status <> 'Cancelled'
    GROUP BY
        b.product_id,
        b.product_sku,
        b.product_name,
        b.category_name
),
returns AS (
    SELECT
        r.product_id,
        SUM(r.return_quantity) AS total_units_returned
    FROM dbo.vw_base_return_detail AS r
    WHERE r.order_status <> 'Cancelled'
    GROUP BY
        r.product_id
)
SELECT
    s.product_id,
    s.product_sku,
    s.product_name,
    s.category_name,
    s.total_units_sold,
    s.net_revenue,
    CAST(
        s.gross_profit * 100.0 / NULLIF(s.net_revenue, 0)
        AS DECIMAL(18,2)
    ) AS gross_margin_percent,
    CAST(
        ISNULL(r.total_units_returned, 0) * 100.0 / NULLIF(s.total_units_sold, 0)
        AS DECIMAL(18,2)
    ) AS return_rate_percent,
    DENSE_RANK() OVER (
        PARTITION BY s.category_name
        ORDER BY s.net_revenue DESC, s.product_id
    ) AS category_revenue_rank
FROM sales AS s
LEFT JOIN returns AS r
    ON s.product_id = r.product_id;
GO

/* Summary view: rep scorecard for current quarter and YTD */
CREATE OR ALTER VIEW dbo.vw_summary_rep_performance
AS
WITH context AS (
    SELECT
        CAST(GETDATE() AS DATE) AS as_of_date,
        YEAR(CAST(GETDATE() AS DATE)) AS report_year,
        DATEPART(QUARTER, CAST(GETDATE() AS DATE)) AS report_quarter
),
rep_catalog AS (
    SELECT
        sr.sales_rep_id,
        sr.employee_code,
        sr.rep_name,
        rr.region_name
    FROM dbo.dim_sales_reps AS sr
    JOIN dbo.dim_regions AS rr
        ON sr.region_id = rr.region_id
    WHERE sr.is_active = 1
),
sales AS (
    SELECT
        b.sales_rep_id,
        CAST(SUM(CASE
            WHEN b.order_year = ctx.report_year
             AND b.order_quarter = ctx.report_quarter
             AND b.order_date <= ctx.as_of_date
                THEN b.net_amount
            ELSE 0
        END) AS DECIMAL(18,2)) AS quarter_to_date_actual_revenue,
        COUNT(DISTINCT CASE
            WHEN b.order_year = ctx.report_year
             AND b.order_quarter = ctx.report_quarter
             AND b.order_date <= ctx.as_of_date
                THEN b.customer_id
        END) AS quarter_to_date_customer_count,
        CAST(SUM(CASE
            WHEN b.order_year = ctx.report_year
             AND b.order_date <= ctx.as_of_date
                THEN b.net_amount
            ELSE 0
        END) AS DECIMAL(18,2)) AS year_to_date_actual_revenue,
        COUNT(DISTINCT CASE
            WHEN b.order_year = ctx.report_year
             AND b.order_date <= ctx.as_of_date
                THEN b.customer_id
        END) AS year_to_date_customer_count
    FROM dbo.vw_base_order_line_detail AS b
    CROSS JOIN context AS ctx
    WHERE b.order_status <> 'Cancelled'
    GROUP BY
        b.sales_rep_id
),
quota AS (
    SELECT
        q.sales_rep_id,
        CAST(SUM(CASE
            WHEN q.quota_period = 'Monthly'
             AND q.quota_year = ctx.report_year
             AND q.quota_quarter = ctx.report_quarter
             AND q.quota_date <= ctx.as_of_date
                THEN q.quota_amount
            ELSE 0
        END) AS DECIMAL(18,2)) AS quarter_to_date_quota,
        CAST(SUM(CASE
            WHEN q.quota_period = 'Monthly'
             AND q.quota_year = ctx.report_year
             AND q.quota_date <= ctx.as_of_date
                THEN q.quota_amount
            ELSE 0
        END) AS DECIMAL(18,2)) AS year_to_date_quota
    FROM dbo.vw_base_quota_detail AS q
    CROSS JOIN context AS ctx
    GROUP BY
        q.sales_rep_id
),
scorecard AS (
    SELECT
        rc.sales_rep_id,
        rc.employee_code,
        rc.rep_name,
        rc.region_name,
        ISNULL(s.quarter_to_date_actual_revenue, 0.00) AS quarter_to_date_actual_revenue,
        ISNULL(q.quarter_to_date_quota, 0.00) AS quarter_to_date_quota,
        CAST(
            ISNULL(s.quarter_to_date_actual_revenue, 0.00) * 100.0
            / NULLIF(ISNULL(q.quarter_to_date_quota, 0.00), 0)
            AS DECIMAL(18,2)
        ) AS quarter_to_date_attainment_percent,
        ISNULL(s.quarter_to_date_customer_count, 0) AS quarter_to_date_customer_count,
        ISNULL(s.year_to_date_actual_revenue, 0.00) AS year_to_date_actual_revenue,
        ISNULL(q.year_to_date_quota, 0.00) AS year_to_date_quota,
        CAST(
            ISNULL(s.year_to_date_actual_revenue, 0.00) * 100.0
            / NULLIF(ISNULL(q.year_to_date_quota, 0.00), 0)
            AS DECIMAL(18,2)
        ) AS year_to_date_attainment_percent,
        ISNULL(s.year_to_date_customer_count, 0) AS year_to_date_customer_count
    FROM rep_catalog AS rc
    LEFT JOIN sales AS s
        ON rc.sales_rep_id = s.sales_rep_id
    LEFT JOIN quota AS q
        ON rc.sales_rep_id = q.sales_rep_id
)
SELECT
    sc.sales_rep_id,
    sc.employee_code,
    sc.rep_name,
    sc.region_name,
    sc.quarter_to_date_actual_revenue,
    sc.quarter_to_date_quota,
    sc.quarter_to_date_attainment_percent,
    sc.quarter_to_date_customer_count,
    RANK() OVER (
        PARTITION BY sc.region_name
        ORDER BY sc.quarter_to_date_attainment_percent DESC, sc.quarter_to_date_actual_revenue DESC, sc.sales_rep_id
    ) AS quarter_rank_in_region,
    sc.year_to_date_actual_revenue,
    sc.year_to_date_quota,
    sc.year_to_date_attainment_percent,
    sc.year_to_date_customer_count
FROM scorecard AS sc;
GO

/* Summary view: monthly trend by country */
CREATE OR ALTER VIEW dbo.vw_summary_monthly_trend
AS
WITH monthly AS (
    SELECT
        DATEFROMPARTS(b.order_year, b.order_month, 1) AS period_start_date,
        b.order_year AS calendar_year,
        b.order_month AS calendar_month,
        b.order_month_name AS month_name,
        b.customer_country_name AS country_name,
        COUNT(DISTINCT b.order_id) AS order_volume,
        SUM(b.net_amount) AS net_revenue,
        CAST(SUM(b.net_amount) * 1.0 / NULLIF(COUNT(DISTINCT b.order_id), 0) AS DECIMAL(18,2)) AS average_order_value
    FROM dbo.vw_base_order_line_detail AS b
    WHERE b.order_status <> 'Cancelled'
    GROUP BY
        DATEFROMPARTS(b.order_year, b.order_month, 1),
        b.order_year,
        b.order_month,
        b.order_month_name,
        b.customer_country_name
),
trend AS (
    SELECT
        m.*,
        LAG(m.net_revenue) OVER (
            PARTITION BY m.country_name
            ORDER BY m.calendar_year, m.calendar_month
        ) AS previous_month_revenue
    FROM monthly AS m
)
SELECT
    period_start_date,
    calendar_year,
    calendar_month,
    month_name,
    country_name,
    order_volume,
    net_revenue,
    average_order_value,
    CAST((net_revenue - previous_month_revenue) * 100.0 / NULLIF(previous_month_revenue, 0) AS DECIMAL(18,2)) AS revenue_change_percent
FROM trend;
GO

/* Summary view: returns by period, country, category, and reason */
CREATE OR ALTER VIEW dbo.vw_summary_returns_analysis
AS
WITH sold AS (
    SELECT
        DATEFROMPARTS(b.order_year, b.order_month, 1) AS period_start_date,
        b.order_year AS calendar_year,
        b.order_month AS calendar_month,
        b.customer_country_name AS country_name,
        b.category_name,
        SUM(b.quantity) AS units_sold
    FROM dbo.vw_base_order_line_detail AS b
    WHERE b.order_status <> 'Cancelled'
    GROUP BY
        DATEFROMPARTS(b.order_year, b.order_month, 1),
        b.order_year,
        b.order_month,
        b.customer_country_name,
        b.category_name
),
returned AS (
    SELECT
        DATEFROMPARTS(r.sale_year, r.sale_month, 1) AS period_start_date,
        r.sale_year AS calendar_year,
        r.sale_month AS calendar_month,
        r.sale_month_name AS month_name,
        r.customer_country_name AS country_name,
        r.category_name,
        r.return_reason,
        SUM(r.return_quantity) AS units_returned,
        SUM(r.credit_amount) AS total_credit_note_value
    FROM dbo.vw_base_return_detail AS r
    WHERE r.order_status <> 'Cancelled'
    GROUP BY
        DATEFROMPARTS(r.sale_year, r.sale_month, 1),
        r.sale_year,
        r.sale_month,
        r.sale_month_name,
        r.customer_country_name,
        r.category_name,
        r.return_reason
)
SELECT
    r.period_start_date,
    r.calendar_year,
    r.calendar_month,
    r.month_name,
    r.country_name,
    r.category_name,
    r.return_reason,
    CAST(r.units_returned * 100.0 / NULLIF(ISNULL(s.units_sold, 0), 0) AS DECIMAL(18,2)) AS return_rate_percent,
    r.total_credit_note_value
FROM returned AS r
LEFT JOIN sold AS s
    ON r.period_start_date = s.period_start_date
   AND r.country_name = s.country_name
   AND r.category_name = s.category_name;
GO

/* =========================================
   TIER 3 - FINAL REPORT VIEWS
   ========================================= */

/* Final view: executive summary */
CREATE OR ALTER VIEW dbo.vw_sales_executive_summary
AS
SELECT
    period_start_date,
    calendar_year,
    calendar_quarter,
    calendar_month,
    month_name,
    country_name,
    region_name,
    order_count,
    total_revenue,
    gross_profit,
    gross_margin_percent,
    average_order_value,
    quota_amount,
    quota_attainment_percent
FROM dbo.vw_summary_sales_executive;
GO

/* Final view: customer 360 */
CREATE OR ALTER VIEW dbo.vw_customer_360
AS
SELECT
    customer_id,
    customer_code,
    customer_name,
    account_tier,
    assigned_rep_name,
    lifetime_revenue,
    order_frequency_last_12_months,
    last_order_date,
    average_order_value,
    return_rate_percent,
    rfm_segment
FROM dbo.vw_summary_customer_360;
GO

/* Final view: product performance */
CREATE OR ALTER VIEW dbo.vw_product_performance
AS
SELECT
    product_id,
    product_sku,
    product_name,
    category_name,
    total_units_sold,
    net_revenue,
    gross_margin_percent,
    return_rate_percent,
    category_revenue_rank
FROM dbo.vw_summary_product_performance;
GO

/* Final view: rep performance scorecard */
CREATE OR ALTER VIEW dbo.vw_rep_performance_scorecard
AS
SELECT
    sales_rep_id,
    employee_code,
    rep_name,
    region_name,
    quarter_to_date_actual_revenue,
    quarter_to_date_quota,
    quarter_to_date_attainment_percent,
    quarter_to_date_customer_count,
    quarter_rank_in_region,
    year_to_date_actual_revenue,
    year_to_date_quota,
    year_to_date_attainment_percent,
    year_to_date_customer_count
FROM dbo.vw_summary_rep_performance;
GO

/* Final view: monthly trend */
CREATE OR ALTER VIEW dbo.vw_monthly_trend
AS
SELECT
    period_start_date,
    calendar_year,
    calendar_month,
    month_name,
    country_name,
    order_volume,
    net_revenue,
    average_order_value,
    revenue_change_percent
FROM dbo.vw_summary_monthly_trend;
GO

/* Final view: returns analysis */
CREATE OR ALTER VIEW dbo.vw_returns_analysis
AS
SELECT
    period_start_date,
    calendar_year,
    calendar_month,
    month_name,
    country_name,
    category_name,
    return_reason,
    return_rate_percent,
    total_credit_note_value
FROM dbo.vw_summary_returns_analysis;
GO
