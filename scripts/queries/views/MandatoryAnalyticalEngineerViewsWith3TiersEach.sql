/* =========================================
   VIEW 1: SALES EXECUTIVE SUMMARY
   ========================================= */

-- 🔹 TIER 1: BASE VIEW
CREATE VIEW vw_base_sales AS
SELECT
    so.order_id,
    so.sales_rep_id,
    c.customer_id,
    r.region_name,
    r.country_name,
    d.year,
    d.month,
    li.quantity,
    li.net_amount,
    p.unit_cost
FROM fact_sales_orders so
JOIN fact_order_line_items li ON so.order_id = li.order_id
JOIN dim_customers c ON so.customer_id = c.customer_id
JOIN dim_regions r ON c.region_id = r.region_id
JOIN dim_products p ON li.product_id = p.product_id
JOIN dim_date d ON so.order_date_id = d.date_id;


-- 🔹 TIER 2: SUMMARY VIEW
CREATE VIEW vw_sales_summary AS
SELECT
    region_name,
    country_name,
    year,
    month,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(net_amount) AS total_revenue,
    SUM(net_amount - (unit_cost * quantity)) AS gross_margin
FROM vw_base_sales
GROUP BY region_name, country_name, year, month;


-- 🔹 TIER 3: FINAL REPORT VIEW
CREATE VIEW vw_sales_executive_summary AS
SELECT
    region_name,
    country_name,
    year,
    month,
    total_revenue,
    gross_margin,
    order_count,
    total_revenue * 1.0 / NULLIF(order_count, 0) AS avg_order_value
FROM vw_sales_summary;
   /* =========================================
   VIEW 2: CUSTOMER 360
   ========================================= */

-- 🔹 TIER 1: BASE VIEW
CREATE VIEW vw_base_customer AS
SELECT
    c.customer_id,
    c.customer_code,
    c.account_tier,
    so.order_id,
    d.full_date,
    li.net_amount
FROM dim_customers c
JOIN fact_sales_orders so ON c.customer_id = so.customer_id
JOIN fact_order_line_items li ON so.order_id = li.order_id
JOIN dim_date d ON so.order_date_id = d.date_id;


-- 🔹 TIER 2: SUMMARY VIEW
CREATE VIEW vw_customer_summary AS
SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(net_amount) AS total_revenue,
    MAX(full_date) AS last_order_date,
    SUM(net_amount) * 1.0 / NULLIF(COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM vw_base_customer
GROUP BY customer_id;


-- 🔹 TIER 3: FINAL VIEW
CREATE VIEW vw_customer_360 AS
SELECT
    c.customer_id,
    c.customer_code,
    c.account_tier,
    s.total_revenue,
    s.total_orders,
    s.last_order_date,
    s.avg_order_value
FROM vw_customer_summary s
JOIN dim_customers c ON s.customer_id = c.customer_id;
