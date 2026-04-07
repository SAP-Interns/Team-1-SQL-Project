/* =========================================
   REPORTING ENGINEER
   WEEK 2 - PHASE 4
   Joins & Multi-Table Logic
   ========================================= */

/* =========================================
   QUERY 1
   Customer Delivery Exception Report
   ========================================= */

-- Business purpose:
-- This report exposes delayed shipments with customer, geography, sales rep,
-- and order value in one result set. It is useful for operational follow-up
-- and is kept intentionally simple for Week 2 defense and review.

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


/* =========================================
   QUERY 2
   Returns Operations Detail Report
   ========================================= */

-- Business purpose:
-- This report joins returns back to the original sale, customer, product,
-- category, and return date. It gives the operations team a clear
-- case-level view of returns and supports the future returns analysis layer.
-- The output is intentionally kept compact so it is easier to explain.

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
