-- Query 1: Calculates total customer revenue and links each customer to their currently assigned sales representative

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_code,
        SUM(li.net_amount) AS total_revenue
    FROM fact_sales_orders so
    JOIN fact_order_line_items li 
        ON so.order_id = li.order_id
    JOIN dim_customers c 
        ON so.customer_id = c.customer_id
    GROUP BY 
        c.customer_id, 
        c.customer_code
)

SELECT
    cr.customer_id,
    cr.customer_code,
    cr.total_revenue,
    sr.rep_name AS assigned_sales_rep
FROM customer_revenue cr
LEFT JOIN rep_customer_assignments rca
    ON cr.customer_id = rca.customer_id
    AND rca.is_active = 1
LEFT JOIN dim_sales_reps sr
    ON rca.sales_rep_id = sr.sales_rep_id
ORDER BY cr.total_revenue DESC;

-- Query 2: Identifies orders that contain multiple products and calculates their total value

SELECT
    so.order_id,
    c.customer_code,
    COUNT(DISTINCT li.product_id) AS number_of_products,
    SUM(li.net_amount) AS total_order_value
FROM fact_sales_orders so
JOIN fact_order_line_items li
    ON so.order_id = li.order_id
JOIN dim_customers c
    ON so.customer_id = c.customer_id
GROUP BY
    so.order_id,
    c.customer_code
HAVING COUNT(DISTINCT li.product_id) > 1
ORDER BY total_order_value DESC;
