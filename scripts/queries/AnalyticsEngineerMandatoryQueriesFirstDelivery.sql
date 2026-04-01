/* =========================================
   QUERY 1
   Customer count per country
   ========================================= */

-- Returns number of customers in each country.

SELECT
    r.country_name,
    COUNT(c.customer_id) AS total_customers
FROM dim_customers AS c
INNER JOIN dim_regions AS r
    ON c.region_id = r.region_id
GROUP BY r.country_name
ORDER BY total_customers DESC;

/* =========================================
   QUERY 2
   Total sales per sales rep
   ========================================= */

-- Returns total net sales amount handled by each sales representative.

SELECT
    sr.sales_rep_id,
    sr.rep_name,
    SUM(li.net_amount) AS total_sales
FROM dim_sales_reps AS sr
INNER JOIN fact_sales_orders AS so
    ON sr.sales_rep_id = so.sales_rep_id
INNER JOIN fact_order_line_items AS li
    ON so.order_id = li.order_id
GROUP BY
    sr.sales_rep_id,
    sr.rep_name
ORDER BY total_sales DESC;
