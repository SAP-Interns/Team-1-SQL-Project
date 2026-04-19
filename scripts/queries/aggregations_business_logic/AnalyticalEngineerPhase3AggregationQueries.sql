--Query 1 – Customer Retention Rate per Year

SELECT
    d.year,
    COUNT(DISTINCT so.customer_id) AS total_customers,
    COUNT(DISTINCT CASE 
        WHEN prev.customer_id IS NOT NULL THEN so.customer_id 
    END) AS returning_customers,
    CAST(
        COUNT(DISTINCT CASE 
            WHEN prev.customer_id IS NOT NULL THEN so.customer_id 
        END) * 100.0 
        / NULLIF(COUNT(DISTINCT so.customer_id), 0)
        AS DECIMAL(18,2)
    ) AS retention_rate_percent
FROM fact_sales_orders so
JOIN dim_date d 
    ON so.order_date_id = d.date_id
LEFT JOIN fact_sales_orders prev
    ON so.customer_id = prev.customer_id
    AND prev.order_date_id < so.order_date_id
GROUP BY d.year
ORDER BY d.year;


--Query 2 – Average Products per Order per Month

SELECT
    d.year,
    d.month,
    COUNT(li.product_id) * 1.0 
        / NULLIF(COUNT(DISTINCT so.order_id), 0) AS avg_products_per_order
FROM fact_sales_orders so
JOIN fact_order_line_items li 
    ON so.order_id = li.order_id
JOIN dim_date d 
    ON so.order_date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
