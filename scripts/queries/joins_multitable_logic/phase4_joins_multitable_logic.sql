
/* =========================================
   QUERY 1
   Full Order Summary
   ========================================= */
SELECT
    so.order_id,
    li.line_item_id,

    od.full_date AS order_date,
    sd.full_date AS ship_date,

    so.order_status,
    so.payment_terms,
    so.document_type,
    so.sales_org,
    so.distribution_channel,

    c.customer_id,
    c.customer_code,
    c.customer_type,
    c.customer_group,
    c.account_tier,

    r.country_name,
    r.region_name,
    r.territory_name,

    sr.sales_rep_id,
    sr.employee_code,
    sr.rep_name,
    sr.job_title,

    p.product_id,
    p.product_sku,
    p.product_name,
    p.brand,
    p.product_type,

    li.quantity,
    li.unit_price,
    li.discount,
    li.gross_amount,
    li.net_amount

FROM fact_sales_orders AS so

INNER JOIN fact_order_line_items AS li
    ON so.order_id = li.order_id

INNER JOIN dim_customers AS c
    ON so.customer_id = c.customer_id

INNER JOIN dim_regions AS r
    ON c.region_id = r.region_id

INNER JOIN dim_sales_reps AS sr
    ON so.sales_rep_id = sr.sales_rep_id

INNER JOIN dim_products AS p
    ON li.product_id = p.product_id

INNER JOIN dim_date AS od
    ON so.order_date_id = od.date_id

LEFT JOIN dim_date AS sd
    ON so.ship_date_id = sd.date_id

ORDER BY
    so.order_id,
    li.line_item_id;





/* =========================================
   QUERY 2
   Orphan Detection
   ========================================= */

SELECT
    c.customer_id,
    c.customer_code,
    c.customer_type,
    c.customer_group,
    c.customer_status,
    c.account_tier,
    c.credit_limit,
    c.is_active,
    c.created_at,
    r.country_name,
    r.region_name,
    r.territory_name
FROM dim_customers AS c
LEFT JOIN fact_sales_orders AS so
    ON c.customer_id = so.customer_id
INNER JOIN dim_regions AS r
    ON c.region_id = r.region_id
WHERE so.order_id IS NULL
ORDER BY
    r.country_name,
    c.customer_code;




/* =========================================
   QUERY 3
   Rep-Customer Mismatch
   ========================================= */

SELECT
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
    c.customer_code;




/* =========================================
   QUERY 4
   Revenue by Geography
   ========================================= */

SELECT
    COALESCE(r.country_name, 'GRAND TOTAL') AS country_name,
    COALESCE(r.region_name, 'ALL REGIONS') AS region_name,
    COALESCE(r.territory_name, 'ALL TERRITORIES') AS territory_name,
    CAST(SUM(li.net_amount) AS DECIMAL(18,2)) AS total_revenue
FROM fact_sales_orders AS so
INNER JOIN fact_order_line_items AS li
    ON so.order_id = li.order_id
INNER JOIN dim_customers AS c
    ON so.customer_id = c.customer_id
INNER JOIN dim_regions AS r
    ON c.region_id = r.region_id
GROUP BY ROLLUP
(
    r.country_name,
    r.region_name,
    r.territory_name
)
ORDER BY
    r.country_name,
    r.region_name,
    r.territory_name;




/* =========================================
   QUERY 5
   Product Cost vs. Actual Sell Price
   ========================================= */

SELECT
    li.line_item_id,
    li.order_id,
    p.product_id,
    p.product_sku,
    p.product_name,
    p.brand,

    li.quantity,
    p.unit_cost,
    li.unit_price,
    li.discount,

    CAST(li.net_amount / NULLIF(li.quantity, 0) AS DECIMAL(18,2)) AS actual_sell_price_per_unit,
    CAST((li.net_amount / NULLIF(li.quantity, 0)) - p.unit_cost AS DECIMAL(18,2)) AS margin_per_unit,
    CAST(li.net_amount - (li.quantity * p.unit_cost) AS DECIMAL(18,2)) AS total_margin,
    CAST(
        ((li.net_amount - (li.quantity * p.unit_cost)) * 100.0)
        / NULLIF(li.net_amount, 0)
        AS DECIMAL(18,2)
    ) AS margin_percent
FROM fact_order_line_items AS li
INNER JOIN dim_products AS p
    ON li.product_id = p.product_id
ORDER BY
    margin_percent DESC,
    li.line_item_id;





/* =========================================
   QUERY 6
   Unordered Products
   ========================================= */

SELECT
    p.product_id,
    p.product_sku,
    p.product_name,
    p.brand,
    p.product_type,
    p.product_status,
    p.stock_level,
    p.list_price,
    p.unit_cost,
    p.is_active
FROM dim_products AS p
LEFT JOIN
(
    SELECT DISTINCT
        li.product_id
    FROM fact_order_line_items AS li
    INNER JOIN dim_date AS d
        ON li.date_id = d.date_id
    WHERE d.full_date >= DATEADD(MONTH, -12, CAST(GETDATE() AS DATE))
) AS recent_sales
    ON p.product_id = recent_sales.product_id
WHERE p.is_active = 1
  AND recent_sales.product_id IS NULL
ORDER BY
    p.stock_level DESC,
    p.product_name;
