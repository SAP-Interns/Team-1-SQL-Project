/* =========================================
   QUERY 1
   Orders per month (last year)
   ========================================= */

-- Returns number of orders per month for the previous year.

SELECT
    d.year,
    d.month,
    COUNT(so.order_id) AS total_orders
FROM fact_sales_orders AS so
INNER JOIN dim_date AS d
    ON so.order_date_id = d.date_id
WHERE d.year = YEAR(GETDATE()) - 1
GROUP BY
    d.year,
    d.month
ORDER BY
    d.month;

/* =========================================
   QUERY 2
   Top 10 most sold products
   ========================================= */

-- Returns top 10 products based on total quantity sold.

SELECT TOP 10
    p.product_id,
    p.product_name,
    SUM(li.quantity) AS total_quantity_sold
FROM dim_products AS p
INNER JOIN fact_order_line_items AS li
    ON p.product_id = li.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_quantity_sold DESC;
