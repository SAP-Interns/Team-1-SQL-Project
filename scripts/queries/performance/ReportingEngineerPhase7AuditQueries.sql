USE NordaTradeDB;
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

/* =========================================
   PHASE 7 AUDIT QUERY 1
   Source: ReportingEngineerPhase4Queries.sql
   Customer Delivery Exception Report
   ========================================= */
SELECT
    so.order_id,
    c.customer_code,
    (
        SELECT r.country_name
        FROM dim_regions AS r
        WHERE r.region_id = c.region_id
    ) AS country_name,
    sr.rep_name,
    (
        SELECT d.full_date
        FROM dim_date AS d
        WHERE d.date_id = so.order_date_id
    ) AS order_date,
    (
        SELECT d.full_date
        FROM dim_date AS d
        WHERE d.date_id = so.ship_date_id
    ) AS ship_date,
    DATEDIFF(
        DAY,
        (
            SELECT d.full_date
            FROM dim_date AS d
            WHERE d.date_id = so.order_date_id
        ),
        (
            SELECT d.full_date
            FROM dim_date AS d
            WHERE d.date_id = so.ship_date_id
        )
    ) AS shipping_delay_days,
    ot.order_net_value
FROM fact_sales_orders AS so
INNER JOIN dim_customers AS c
    ON so.customer_id = c.customer_id
INNER JOIN dim_sales_reps AS sr
    ON so.sales_rep_id = sr.sales_rep_id
INNER JOIN
(
    SELECT
        order_id,
        CAST(SUM(net_amount) AS DECIMAL(18,2)) AS order_net_value
    FROM fact_order_line_items
    GROUP BY
        order_id
) AS ot
    ON so.order_id = ot.order_id
WHERE so.ship_date_id IS NOT NULL
  AND so.order_status <> 'Cancelled'
  AND DATEDIFF(
        DAY,
        (
            SELECT d.full_date
            FROM dim_date AS d
            WHERE d.date_id = so.order_date_id
        ),
        (
            SELECT d.full_date
            FROM dim_date AS d
            WHERE d.date_id = so.ship_date_id
        )
    ) > 14
ORDER BY
    shipping_delay_days DESC,
    ot.order_net_value DESC,
    so.order_id;
GO

/* =========================================
   PHASE 7 AUDIT QUERY 2
   Source: ReportingEngineerPhase4Queries.sql
   Returns Operations Detail Report
   ========================================= */
SELECT
    fr.return_id,
    (
        SELECT d.full_date
        FROM dim_date AS d
        WHERE d.date_id = fr.date_id
    ) AS return_date,
    so.order_id,
    (
        SELECT c.customer_code
        FROM dim_customers AS c
        WHERE c.customer_id = so.customer_id
    ) AS customer_code,
    p.product_name,
    (
        SELECT cat.category_name
        FROM dim_categories AS cat
        WHERE cat.category_id = p.category_id
    ) AS category_name,
    fr.return_quantity,
    CAST(fr.credit_amount AS DECIMAL(18,2)) AS credit_amount,
    fr.return_reason
FROM fact_returns AS fr
INNER JOIN fact_order_line_items AS li
    ON fr.line_item_id = li.line_item_id
INNER JOIN fact_sales_orders AS so
    ON li.order_id = so.order_id
INNER JOIN dim_products AS p
    ON li.product_id = p.product_id
ORDER BY
    return_date DESC,
    fr.credit_amount DESC,
    so.order_id,
    li.line_item_id;
GO

/* =========================================
   PHASE 7 AUDIT QUERY 3
   Source: ReportingEngineerAdvanceQueries.sql
   Customer 360 Candidate Dataset
   ========================================= */
WITH customer_order_metrics AS (
    SELECT
        so.customer_id,
        COUNT(DISTINCT so.order_id) AS order_count,
        CAST(SUM(li.net_amount) AS DECIMAL(18,2)) AS lifetime_revenue,
        CAST(
            SUM(li.net_amount) * 1.0
            / NULLIF(COUNT(DISTINCT so.order_id), 0)
            AS DECIMAL(18,2)
        ) AS average_order_value,
        MAX(d.full_date) AS last_order_date
    FROM fact_sales_orders AS so
    INNER JOIN fact_order_line_items AS li
        ON so.order_id = li.order_id
    INNER JOIN dim_date AS d
        ON so.order_date_id = d.date_id
    WHERE so.order_status <> 'Cancelled'
    GROUP BY
        so.customer_id
),
customer_return_metrics AS (
    SELECT
        so.customer_id,
        COUNT(fr.return_id) AS return_count,
        CAST(COALESCE(SUM(fr.credit_amount), 0.00) AS DECIMAL(18,2)) AS total_credit_amount
    FROM fact_sales_orders AS so
    INNER JOIN fact_order_line_items AS li
        ON so.order_id = li.order_id
    LEFT JOIN fact_returns AS fr
        ON li.line_item_id = fr.line_item_id
    GROUP BY
        so.customer_id
),
current_assignment AS (
    SELECT
        customer_id,
        sales_rep_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY valid_from DESC, assignment_id DESC
        ) AS assignment_rank
    FROM rep_customer_assignments
    WHERE is_active = 1
      AND valid_from <= CAST(GETDATE() AS DATE)
      AND (valid_to IS NULL OR valid_to >= CAST(GETDATE() AS DATE))
),
customer_profile AS (
    SELECT
        c.customer_id,
        c.customer_code,
        c.customer_name,
        c.account_tier,
        r.country_name,
        om.order_count,
        om.lifetime_revenue,
        om.average_order_value,
        om.last_order_date,
        COALESCE(rm.return_count, 0) AS return_count,
        COALESCE(rm.total_credit_amount, 0.00) AS total_credit_amount,
        sr.rep_name AS assigned_rep_name
    FROM dim_customers AS c
    INNER JOIN dim_regions AS r
        ON c.region_id = r.region_id
    INNER JOIN customer_order_metrics AS om
        ON c.customer_id = om.customer_id
    LEFT JOIN customer_return_metrics AS rm
        ON c.customer_id = rm.customer_id
    LEFT JOIN current_assignment AS ca
        ON c.customer_id = ca.customer_id
       AND ca.assignment_rank = 1
    LEFT JOIN dim_sales_reps AS sr
        ON ca.sales_rep_id = sr.sales_rep_id
)
SELECT
    cp.customer_id,
    cp.customer_code,
    cp.customer_name,
    cp.account_tier,
    cp.country_name,
    cp.assigned_rep_name,
    cp.order_count,
    cp.lifetime_revenue,
    cp.average_order_value,
    cp.last_order_date,
    DATEDIFF(DAY, cp.last_order_date, CAST(GETDATE() AS DATE)) AS days_since_last_order,
    cp.return_count,
    cp.total_credit_amount,
    DENSE_RANK() OVER (
        PARTITION BY cp.country_name
        ORDER BY cp.lifetime_revenue DESC
    ) AS lifetime_revenue_rank_in_country
FROM customer_profile AS cp
ORDER BY
    cp.country_name,
    lifetime_revenue_rank_in_country,
    cp.customer_code;
GO

/* =========================================
   PHASE 7 AUDIT QUERY 4
   Source: ReportingEngineerAdvanceQueries.sql
   Monthly Country Trend Dataset
   ========================================= */
WITH monthly_country_metrics AS (
    SELECT
        d.year,
        d.month,
        d.month_name,
        r.country_name,
        COUNT(DISTINCT so.order_id) AS order_volume,
        CAST(SUM(li.net_amount) AS DECIMAL(18,2)) AS net_revenue,
        CAST(
            SUM(li.net_amount) * 1.0
            / NULLIF(COUNT(DISTINCT so.order_id), 0)
            AS DECIMAL(18,2)
        ) AS average_order_value
    FROM fact_sales_orders AS so
    INNER JOIN fact_order_line_items AS li
        ON so.order_id = li.order_id
    INNER JOIN dim_customers AS c
        ON so.customer_id = c.customer_id
    INNER JOIN dim_regions AS r
        ON c.region_id = r.region_id
    INNER JOIN dim_date AS d
        ON so.order_date_id = d.date_id
    WHERE so.order_status <> 'Cancelled'
    GROUP BY
        d.year,
        d.month,
        d.month_name,
        r.country_name
),
country_trend AS (
    SELECT
        mcm.year,
        mcm.month,
        mcm.month_name,
        mcm.country_name,
        mcm.order_volume,
        mcm.net_revenue,
        mcm.average_order_value,
        LAG(mcm.net_revenue) OVER (
            PARTITION BY mcm.country_name
            ORDER BY mcm.year, mcm.month
        ) AS previous_month_revenue,
        SUM(mcm.net_revenue) OVER (
            PARTITION BY mcm.country_name, mcm.year
            ORDER BY mcm.month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_year_revenue
    FROM monthly_country_metrics AS mcm
)
SELECT
    ct.year,
    ct.month,
    ct.month_name,
    ct.country_name,
    ct.order_volume,
    ct.net_revenue,
    ct.average_order_value,
    ct.previous_month_revenue,
    CAST(ct.net_revenue - ct.previous_month_revenue AS DECIMAL(18,2)) AS revenue_change,
    CAST(
        (ct.net_revenue - ct.previous_month_revenue) * 100.0
        / NULLIF(ct.previous_month_revenue, 0)
        AS DECIMAL(18,2)
    ) AS revenue_change_percent,
    ct.running_year_revenue
FROM country_trend AS ct
ORDER BY
    ct.country_name,
    ct.year,
    ct.month;
GO

/* =========================================
   PHASE 7 AUDIT QUERY 5
   Source: phase4_joins_multitable_logic.sql
   Rep-Customer Mismatch
   ========================================= */
SELECT TOP (100)
    so.order_id,
    c.customer_id,
    c.customer_code,
    c.account_tier,
    so.sales_rep_id AS processing_sales_rep_id,
    sr_processed.employee_code AS processing_employee_code,
    sr_processed.rep_name AS processing_rep_name,
    a.sales_rep_id AS assigned_sales_rep_id,
    sr_assigned.employee_code AS assigned_employee_code,
    sr_assigned.rep_name AS assigned_rep_name,
    od.full_date AS order_date,
    so.order_status
FROM fact_sales_orders AS so
INNER JOIN dim_customers AS c
    ON so.customer_id = c.customer_id
INNER JOIN dim_date AS od
    ON so.order_date_id = od.date_id
INNER JOIN rep_customer_assignments AS a
    ON c.customer_id = a.customer_id
   AND od.full_date >= a.valid_from
   AND (a.valid_to IS NULL OR od.full_date <= a.valid_to)
INNER JOIN dim_sales_reps AS sr_processed
    ON so.sales_rep_id = sr_processed.sales_rep_id
INNER JOIN dim_sales_reps AS sr_assigned
    ON a.sales_rep_id = sr_assigned.sales_rep_id
WHERE so.sales_rep_id <> a.sales_rep_id
ORDER BY
    od.full_date DESC,
    c.customer_code,
    so.order_id;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
