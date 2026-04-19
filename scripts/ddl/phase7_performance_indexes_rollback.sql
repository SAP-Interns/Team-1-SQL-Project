USE NordaTradeDB;
GO

/* =========================================
   REPORTING ENGINEER
   WEEK 3 - PHASE 7
   PERFORMANCE INDEX ROLLBACK
   ========================================= */

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_sales_orders_customer_order_date'
      AND object_id = OBJECT_ID('dbo.fact_sales_orders')
)
DROP INDEX IX_fact_sales_orders_customer_order_date
    ON dbo.fact_sales_orders;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_sales_orders_sales_rep_order_date'
      AND object_id = OBJECT_ID('dbo.fact_sales_orders')
)
DROP INDEX IX_fact_sales_orders_sales_rep_order_date
    ON dbo.fact_sales_orders;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_sales_orders_order_status_order_date'
      AND object_id = OBJECT_ID('dbo.fact_sales_orders')
)
DROP INDEX IX_fact_sales_orders_order_status_order_date
    ON dbo.fact_sales_orders;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_order_line_items_order'
      AND object_id = OBJECT_ID('dbo.fact_order_line_items')
)
DROP INDEX IX_fact_order_line_items_order
    ON dbo.fact_order_line_items;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_order_line_items_product_date'
      AND object_id = OBJECT_ID('dbo.fact_order_line_items')
)
DROP INDEX IX_fact_order_line_items_product_date
    ON dbo.fact_order_line_items;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_order_line_items_date_order'
      AND object_id = OBJECT_ID('dbo.fact_order_line_items')
)
DROP INDEX IX_fact_order_line_items_date_order
    ON dbo.fact_order_line_items;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_returns_line_item'
      AND object_id = OBJECT_ID('dbo.fact_returns')
)
DROP INDEX IX_fact_returns_line_item
    ON dbo.fact_returns;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_returns_date_reason'
      AND object_id = OBJECT_ID('dbo.fact_returns')
)
DROP INDEX IX_fact_returns_date_reason
    ON dbo.fact_returns;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_quotas_sales_rep_date_period'
      AND object_id = OBJECT_ID('dbo.fact_quotas')
)
DROP INDEX IX_fact_quotas_sales_rep_date_period
    ON dbo.fact_quotas;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_fact_quotas_date_period'
      AND object_id = OBJECT_ID('dbo.fact_quotas')
)
DROP INDEX IX_fact_quotas_date_period
    ON dbo.fact_quotas;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_rep_customer_assignments_customer_active_window'
      AND object_id = OBJECT_ID('dbo.rep_customer_assignments')
)
DROP INDEX IX_rep_customer_assignments_customer_active_window
    ON dbo.rep_customer_assignments;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_rep_customer_assignments_sales_rep_active_window'
      AND object_id = OBJECT_ID('dbo.rep_customer_assignments')
)
DROP INDEX IX_rep_customer_assignments_sales_rep_active_window
    ON dbo.rep_customer_assignments;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_dim_customers_region'
      AND object_id = OBJECT_ID('dbo.dim_customers')
)
DROP INDEX IX_dim_customers_region
    ON dbo.dim_customers;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_dim_sales_reps_region'
      AND object_id = OBJECT_ID('dbo.dim_sales_reps')
)
DROP INDEX IX_dim_sales_reps_region
    ON dbo.dim_sales_reps;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_dim_products_category'
      AND object_id = OBJECT_ID('dbo.dim_products')
)
DROP INDEX IX_dim_products_category
    ON dbo.dim_products;
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_product_promotions_product_window'
      AND object_id = OBJECT_ID('dbo.product_promotions')
)
DROP INDEX IX_product_promotions_product_window
    ON dbo.product_promotions;
GO
