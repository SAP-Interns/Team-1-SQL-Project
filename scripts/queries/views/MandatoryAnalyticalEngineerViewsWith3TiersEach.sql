/* =========================================
   VIEW: SALES CHANNEL ANALYSIS
   ========================================= */

-- 🔹 TIER 1: BASE
CREATE VIEW vw_base_channel AS
SELECT
    so.order_id,
    c.customer_id,
    c.account_tier,
    r.region_name,
    r.country_name,
    d.year,
    d.month,
    li.quantity,
    li.net_amount
FROM fact_sales_orders so
JOIN fact_order_line_items li ON so.order_id = li.order_id
JOIN dim_customers c ON so.customer_id = c.customer_id
JOIN dim_regions r ON c.region_id = r.region_id
JOIN dim_date d ON so.order_date_id = d.date_id;


-- 🔹 TIER 2: SUMMARY
CREATE VIEW vw_channel_summary AS
SELECT
    region_name,
    country_name,
    account_tier,
    year,
    month,
    SUM(net_amount) AS total_revenue,
    SUM(quantity) AS total_units,
    COUNT(DISTINCT customer_id) AS customer_count
FROM vw_base_channel
GROUP BY region_name, country_name, account_tier, year, month;


-- 🔹 TIER 3: FINAL VIEW
CREATE VIEW vw_sales_channel_analysis AS
SELECT
    region_name,
    country_name,
    account_tier,
    year,
    month,
    total_revenue,
    total_units,
    customer_count,
    total_revenue * 1.0 / NULLIF(customer_count, 0) AS revenue_per_customer
FROM vw_channel_summary;


/* =========================================
   VIEW: ORDER EFFICIENCY
   ========================================= */

-- 🔹 TIER 1: BASE
CREATE VIEW vw_base_orders AS
SELECT
    so.order_id,
    so.sales_rep_id,
    d.year,
    d.month,
    li.quantity,
    li.net_amount
FROM fact_sales_orders so
JOIN fact_order_line_items li ON so.order_id = li.order_id
JOIN dim_date d ON so.order_date_id = d.date_id;


-- 🔹 TIER 2: SUMMARY
CREATE VIEW vw_order_summary AS
SELECT
    sales_rep_id,
    year,
    month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS total_units,
    SUM(net_amount) AS total_revenue
FROM vw_base_orders
GROUP BY sales_rep_id, year, month;


-- 🔹 TIER 3: FINAL VIEW
CREATE VIEW vw_order_efficiency AS
SELECT
    s.sales_rep_id,
    sr.rep_name,
    s.year,
    s.month,
    s.total_orders,
    s.total_units,
    s.total_revenue,
    s.total_units * 1.0 / NULLIF(s.total_orders, 0) AS avg_units_per_order,
    s.total_revenue * 1.0 / NULLIF(s.total_orders, 0) AS avg_order_value
FROM vw_order_summary s
JOIN dim_sales_reps sr ON s.sales_rep_id = sr.sales_rep_id;
