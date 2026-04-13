
-- Advance Analytical Queries

/* 
    1. Customer RFM Segmentation (CTE Required): Using a multi-step CTE, compute each customer's Recency (days since last order),
    Frequency (number of orders in the past year), and Monetary (total spend in the past year) scores. Then classify
    each customer into one of five segments: Champions, Loyal, At Risk, Lost, and New - using scoring logic you define and document.
*/
WITH customer_orders AS (
    SELECT
        c.customer_id,
        MAX(d.full_date) AS last_order_date,
        COUNT(DISTINCT so.order_id) AS frequency,
        SUM(li.net_amount) AS monetary
    FROM fact_sales_orders so
    JOIN fact_order_line_items li ON so.order_id = li.order_id
    JOIN dim_customers c ON so.customer_id = c.customer_id
    JOIN dim_date d ON so.order_date_id = d.date_id
    WHERE d.full_date >= DATEADD(YEAR, -1, GETDATE())
    GROUP BY c.customer_id
),
rfm_scores AS (
    SELECT
        customer_id,
        DATEDIFF(DAY, last_order_date, GETDATE()) AS recency,
        frequency,
        monetary
    FROM customer_orders
)
SELECT
    *,
    CASE
        WHEN recency <= 30 AND frequency >= 10 AND monetary >= 10000 THEN 'Champions'
        WHEN recency <= 60 AND frequency >= 5 THEN 'Loyal'
        WHEN recency > 90 AND frequency < 3 THEN 'At Risk'
        WHEN recency > 180 THEN 'Lost'
        ELSE 'New'
    END AS customer_segment
FROM rfm_scores;

/* 
      2. Month-over-Month Revenue Change (LAG Required): Using the LAG window function,
      produce a report showing each month's net revenue alongside the previous month's net revenue,
      the absolute change, and the percentage change. Partition by country so each country's trend is independent.
*/
        WITH monthly_revenue AS (
    SELECT
        r.country_name,
        d.year,
        d.month,
        SUM(li.net_amount) AS current_revenue
    FROM fact_order_line_items li
    JOIN dim_date d 
        ON li.date_id = d.date_id
    JOIN fact_sales_orders so 
        ON li.order_id = so.order_id
    JOIN dim_customers c 
        ON so.customer_id = c.customer_id
    JOIN dim_regions r 
        ON c.region_id = r.region_id
    GROUP BY 
        r.country_name, 
        d.year, 
        d.month
)

SELECT
    country_name,
    year,
    month,
    current_revenue,
    LAG(current_revenue) OVER (
        PARTITION BY country_name
        ORDER BY year, month
    ) AS previous_revenue,
    current_revenue 
        - LAG(current_revenue) OVER (
            PARTITION BY country_name
            ORDER BY year, month
        ) AS revenue_change,
    (current_revenue 
        - LAG(current_revenue) OVER (
            PARTITION BY country_name
            ORDER BY year, month
        )
    ) * 100.0
    / NULLIF(
        LAG(current_revenue) OVER (
            PARTITION BY country_name
            ORDER BY year, month
        ), 0
    ) AS percentage_change
FROM monthly_revenue; 

/* 
      3. Running Total by Quarter (SUM OVER Required): Produce a cumulative revenue report showing, for each order,
      the running total of net revenue within its calendar quarter, partitioned by sales region.
*/

    SELECT
    r.region_name,
    d.year,
    d.quarter,
    so.order_id,
    SUM(li.net_amount) AS order_revenue,
    SUM(SUM(li.net_amount)) OVER (
        PARTITION BY r.region_name, d.year, d.quarter
        ORDER BY so.order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM fact_sales_orders so
JOIN fact_order_line_items li ON so.order_id = li.order_id
JOIN dim_date d ON so.order_date_id = d.date_id
JOIN dim_customers c ON so.customer_id = c.customer_id
JOIN dim_regions r ON c.region_id = r.region_id
GROUP BY r.region_name, d.year, d.quarter, so.order_id;

/* 
      4. Rank Sales Reps Within Region (RANK Required): Rank all sales representatives by quota attainment percentage within
      their assigned region for the most recent complete quarter. Show the rank, the rep's name, their attainment,
      and the region average attainment.
*/

WITH rep_performance AS (
    SELECT
        r.region_name,
        sr.sales_rep_id,
        sr.rep_name,
        SUM(li.net_amount) AS actual_revenue,
        SUM(q.quota_amount) AS quota,
        SUM(li.net_amount) * 100.0 / NULLIF(SUM(q.quota_amount),0) AS attainment
    FROM fact_sales_orders so
    JOIN fact_order_line_items li ON so.order_id = li.order_id
    JOIN dim_sales_reps sr ON so.sales_rep_id = sr.sales_rep_id
    JOIN dim_regions r ON sr.region_id = r.region_id
    JOIN fact_quotas q ON sr.sales_rep_id = q.sales_rep_id
    JOIN dim_date d ON q.date_id = d.date_id
    WHERE d.year = YEAR(GETDATE()) - 1
    GROUP BY r.region_name, sr.sales_rep_id, sr.rep_name
)
SELECT
    *,
    RANK() OVER (
        PARTITION BY region_name
        ORDER BY attainment DESC
    ) AS rank_in_region,
    AVG(attainment) OVER (
        PARTITION BY region_name
    ) AS region_avg
FROM rep_performance;

/* 
      5. Top Customer Per Country (ROW_NUMBER + Subquery): Using a subquery or CTE with ROW_NUMBER(),
      identify the single highest-revenue customer in each country for the current year,
      showing their name, country, total revenue, and account tier.
*/

WITH customer_revenue AS (
    SELECT
        r.country_name,
        c.customer_id,
        c.customer_code,  
        c.account_tier,
        SUM(li.net_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY r.country_name
            ORDER BY SUM(li.net_amount) DESC
        ) AS rn
    FROM fact_sales_orders so
    JOIN fact_order_line_items li ON so.order_id = li.order_id
    JOIN dim_customers c ON so.customer_id = c.customer_id
    JOIN dim_regions r ON c.region_id = r.region_id
    JOIN dim_date d ON so.order_date_id = d.date_id
    WHERE d.year = YEAR(GETDATE())
    GROUP BY r.country_name, c.customer_id, c.customer_code, c.account_tier
)
SELECT
    country_name,
    customer_id,
    customer_code,
    account_tier,
    total_revenue
FROM customer_revenue
WHERE rn = 1;

/* 
      6. Products Never Ordered in High-Revenue Regions (Correlated Subquery): Identify products that have never
         been ordered by any customer in regions that generated more than €1M in revenue in the past year.
         Use a correlated subquery in the WHERE clause.
*/

SELECT p.product_id, p.product_name
FROM dim_products p
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_order_line_items li
    JOIN fact_sales_orders so ON li.order_id = so.order_id
    JOIN dim_customers c ON so.customer_id = c.customer_id
    JOIN dim_regions r ON c.region_id = r.region_id
    JOIN dim_date d ON li.date_id = d.date_id
    WHERE li.product_id = p.product_id
    AND r.region_id IN (
        SELECT r2.region_id
        FROM fact_order_line_items li2
        JOIN fact_sales_orders so2 ON li2.order_id = so2.order_id
        JOIN dim_customers c2 ON so2.customer_id = c2.customer_id
        JOIN dim_regions r2 ON c2.region_id = r2.region_id
        JOIN dim_date d2 ON li2.date_id = d2.date_id
        WHERE d2.year = YEAR(GETDATE()) - 1
        GROUP BY r2.region_id
        HAVING SUM(li2.net_amount) > 1000000
    )
);

