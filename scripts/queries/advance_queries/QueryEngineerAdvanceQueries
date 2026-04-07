-- Advance Analytical Queries (Extra)

/* 
    1. Top 3 Customers in Each Country by Quarterly Revenue:

*/
WITH customer_quarter_revenue AS (
    SELECT
        r.country_name,
        d.year,
        d.quarter,
        c.customer_id,
        c.customer_code,
        c.account_tier,
        SUM(li.net_amount) AS total_revenue
    FROM fact_sales_orders AS so
    INNER JOIN fact_order_line_items AS li
        ON so.order_id = li.order_id
    INNER JOIN dim_customers AS c
        ON so.customer_id = c.customer_id
    INNER JOIN dim_regions AS r
        ON c.region_id = r.region_id
    INNER JOIN dim_date AS d
        ON so.order_date_id = d.date_id
    GROUP BY
        r.country_name,
        d.year,
        d.quarter,
        c.customer_id,
        c.customer_code,
        c.account_tier
),
ranked_customers AS (
    SELECT
        country_name,
        year,
        quarter,
        customer_id,
        customer_code,
        account_tier,
        total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY country_name, year, quarter
            ORDER BY total_revenue DESC
        ) AS revenue_rank
    FROM customer_quarter_revenue
)
SELECT
    country_name,
    year,
    quarter,
    customer_id,
    customer_code,
    account_tier,
    total_revenue,
    revenue_rank
FROM ranked_customers
WHERE revenue_rank <= 3
ORDER BY country_name, year, quarter, revenue_rank, total_revenue DESC;


/* 
    2. Monthly Product Revenue with Running Total by Category:

*/
WITH monthly_product_revenue AS (
    SELECT
        cat.category_name,
        p.product_id,
        p.product_sku,
        p.product_name,
        d.year,
        d.month,
        d.month_name,
        SUM(li.net_amount) AS monthly_revenue
    FROM fact_order_line_items AS li
    INNER JOIN dim_products AS p
        ON li.product_id = p.product_id
    INNER JOIN dim_categories AS cat
        ON p.category_id = cat.category_id
    INNER JOIN dim_date AS d
        ON li.date_id = d.date_id
    GROUP BY
        cat.category_name,
        p.product_id,
        p.product_sku,
        p.product_name,
        d.year,
        d.month,
        d.month_name
)
SELECT
    category_name,
    product_id,
    product_sku,
    product_name,
    year,
    month,
    month_name,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY category_name, product_id, year
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_year_total
FROM monthly_product_revenue
ORDER BY category_name, product_name, year, month;
