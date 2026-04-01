/* =========================================
   QUERY 1
   Active products never ordered
   ========================================= */

SELECT
    p.product_id,
    p.product_sku,
    p.product_name,
    p.brand,
    p.list_price,
    p.stock_level
FROM dim_products AS p
LEFT JOIN fact_order_line_items AS li
    ON p.product_id = li.product_id
WHERE p.is_active = 1
  AND li.line_item_id IS NULL
ORDER BY
    p.stock_level DESC,
    p.product_name;

/* =========================================
   QUERY 2
   Average order value per customer
   ========================================= */

SELECT 
    so.customer_id,
    AVG(li.net_amount) AS avg_order_value
FROM fact_sales_orders so
JOIN fact_order_line_items li 
    ON so.order_id = li.order_id
GROUP BY so.customer_id;