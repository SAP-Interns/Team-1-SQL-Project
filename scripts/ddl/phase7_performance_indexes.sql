USE NordaTradeDB;
GO

/* =========================================
   REPORTING ENGINEER
   WEEK 3 - PHASE 7
   PERFORMANCE INDEX PACKAGE
   ========================================= */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_sales_orders_customer_order_date'
      AND object_id = OBJECT_ID('dbo.fact_sales_orders')
)
CREATE INDEX IX_fact_sales_orders_customer_order_date
    ON dbo.fact_sales_orders (customer_id, order_date_id)
    INCLUDE (order_id, sales_rep_id, order_status, ship_date_id);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_sales_orders_sales_rep_order_date'
      AND object_id = OBJECT_ID('dbo.fact_sales_orders')
)
CREATE INDEX IX_fact_sales_orders_sales_rep_order_date
    ON dbo.fact_sales_orders (sales_rep_id, order_date_id)
    INCLUDE (order_id, customer_id, order_status, ship_date_id);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_sales_orders_order_status_order_date'
      AND object_id = OBJECT_ID('dbo.fact_sales_orders')
)
CREATE INDEX IX_fact_sales_orders_order_status_order_date
    ON dbo.fact_sales_orders (order_status, order_date_id)
    INCLUDE (order_id, customer_id, sales_rep_id, ship_date_id, distribution_channel);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_order_line_items_order'
      AND object_id = OBJECT_ID('dbo.fact_order_line_items')
)
CREATE INDEX IX_fact_order_line_items_order
    ON dbo.fact_order_line_items (order_id)
    INCLUDE (product_id, date_id, quantity, unit_price, discount, gross_amount, net_amount);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_order_line_items_product_date'
      AND object_id = OBJECT_ID('dbo.fact_order_line_items')
)
CREATE INDEX IX_fact_order_line_items_product_date
    ON dbo.fact_order_line_items (product_id, date_id)
    INCLUDE (order_id, quantity, unit_price, gross_amount, net_amount);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_order_line_items_date_order'
      AND object_id = OBJECT_ID('dbo.fact_order_line_items')
)
CREATE INDEX IX_fact_order_line_items_date_order
    ON dbo.fact_order_line_items (date_id, order_id)
    INCLUDE (product_id, quantity, gross_amount, net_amount);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_returns_line_item'
      AND object_id = OBJECT_ID('dbo.fact_returns')
)
CREATE INDEX IX_fact_returns_line_item
    ON dbo.fact_returns (line_item_id)
    INCLUDE (date_id, return_status, return_quantity, credit_amount, return_reason);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_returns_date_reason'
      AND object_id = OBJECT_ID('dbo.fact_returns')
)
CREATE INDEX IX_fact_returns_date_reason
    ON dbo.fact_returns (date_id, return_reason)
    INCLUDE (line_item_id, return_status, return_quantity, credit_amount);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_quotas_sales_rep_date_period'
      AND object_id = OBJECT_ID('dbo.fact_quotas')
)
CREATE INDEX IX_fact_quotas_sales_rep_date_period
    ON dbo.fact_quotas (sales_rep_id, date_id, quota_period)
    INCLUDE (quota_amount);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_quotas_date_period'
      AND object_id = OBJECT_ID('dbo.fact_quotas')
)
CREATE INDEX IX_fact_quotas_date_period
    ON dbo.fact_quotas (date_id, quota_period)
    INCLUDE (sales_rep_id, quota_amount);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_rep_customer_assignments_customer_active_window'
      AND object_id = OBJECT_ID('dbo.rep_customer_assignments')
)
CREATE INDEX IX_rep_customer_assignments_customer_active_window
    ON dbo.rep_customer_assignments (customer_id, is_active, valid_from, valid_to)
    INCLUDE (sales_rep_id);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_rep_customer_assignments_sales_rep_active_window'
      AND object_id = OBJECT_ID('dbo.rep_customer_assignments')
)
CREATE INDEX IX_rep_customer_assignments_sales_rep_active_window
    ON dbo.rep_customer_assignments (sales_rep_id, is_active, valid_from, valid_to)
    INCLUDE (customer_id);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_dim_customers_region'
      AND object_id = OBJECT_ID('dbo.dim_customers')
)
CREATE INDEX IX_dim_customers_region
    ON dbo.dim_customers (region_id)
    INCLUDE (customer_id, customer_code, customer_name, account_tier, customer_status, customer_type, customer_group);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_dim_sales_reps_region'
      AND object_id = OBJECT_ID('dbo.dim_sales_reps')
)
CREATE INDEX IX_dim_sales_reps_region
    ON dbo.dim_sales_reps (region_id)
    INCLUDE (sales_rep_id, employee_code, rep_name, sales_rep_status, is_active);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_dim_products_category'
      AND object_id = OBJECT_ID('dbo.dim_products')
)
CREATE INDEX IX_dim_products_category
    ON dbo.dim_products (category_id)
    INCLUDE (product_id, product_sku, product_name, product_status, unit_cost, list_price, brand);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_product_promotions_product_window'
      AND object_id = OBJECT_ID('dbo.product_promotions')
)
CREATE INDEX IX_product_promotions_product_window
    ON dbo.product_promotions (product_id, valid_from, valid_to)
    INCLUDE (discount_rate);
GO
