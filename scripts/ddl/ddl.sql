USE NordaTradeDB;
GO

  

DROP TABLE IF EXISTS product_promotions;
DROP TABLE IF EXISTS rep_customer_assignments;
DROP TABLE IF EXISTS fact_quotas;
DROP TABLE IF EXISTS fact_returns;
DROP TABLE IF EXISTS fact_order_line_items;
DROP TABLE IF EXISTS fact_sales_orders;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;
DROP TABLE IF EXISTS dim_sales_reps;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_categories;
DROP TABLE IF EXISTS dim_regions;
GO


  -- DIMENSION TABLES
 
CREATE TABLE dim_regions (
  country_id INT IDENTITY(1,1) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    territory_name VARCHAR(100) NOT NULL,
    CONSTRAINT PK_dim_regions PRIMARY KEY (country_id)
);
GO

CREATE TABLE dim_categories (
    category_id INT IDENTITY(1,1) NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    segment_name VARCHAR(100) NOT NULL,
    parent_category_id INT NULL,
    CONSTRAINT PK_dim_categories PRIMARY KEY (category_id),
    CONSTRAINT FK_dim_categories_parent
        FOREIGN KEY (parent_category_id) REFERENCES dim_categories(category_id)
);
GO

CREATE TABLE dim_date (
    date_id INT IDENTITY(1,1) NOT NULL,
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    week_number INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_business_day BIT NOT NULL,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_id),
    CONSTRAINT UQ_dim_date_full_date UNIQUE (full_date),
    CONSTRAINT CHK_dim_date_quarter CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT CHK_dim_date_month CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT CHK_dim_date_day_of_week CHECK (day_of_week BETWEEN 1 AND 7)
);
GO

CREATE TABLE dim_sales_reps (
    sales_rep_id INT IDENTITY(1,1) NOT NULL,
    employee_code VARCHAR(50) NOT NULL,
    rep_name VARCHAR(100) NOT NULL,
    hire_date DATE NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    sales_rep_status VARCHAR(50) NOT NULL DEFAULT 'Active',
    is_active BIT NOT NULL DEFAULT 1,
    valid_from DATE NOT NULL,
    valid_to DATE NULL,
   country_id INT NOT NULL,
    CONSTRAINT PK_dim_sales_reps PRIMARY KEY (sales_rep_id),
    CONSTRAINT UQ_dim_sales_reps_employee_code UNIQUE (employee_code),
    CONSTRAINT FK_dim_sales_reps_region
        FOREIGN KEY (country_id) REFERENCES dim_regions(country_id),
    CONSTRAINT CHK_dim_sales_reps_valid_dates
        CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
GO

CREATE TABLE dim_customers (
    customer_id INT IDENTITY(1,1) NOT NULL,
    customer_type VARCHAR(50) NOT NULL,
    customer_group VARCHAR(100) NOT NULL,
    customer_status VARCHAR(50) NOT NULL DEFAULT 'Active',
    account_tier VARCHAR(20) NOT NULL,
    credit_limit DECIMAL(18,2) NOT NULL,
    billing_address VARCHAR(255) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    customer_code VARCHAR(50) NOT NULL,
  country_id INT NOT NULL,
    CONSTRAINT PK_dim_customers PRIMARY KEY (customer_id),
    CONSTRAINT UQ_dim_customers_customer_code UNIQUE (customer_code),
    CONSTRAINT FK_dim_customers_region
        FOREIGN KEY (country_id) REFERENCES dim_regions(country_id),
    CONSTRAINT CHK_dim_customers_credit_limit CHECK (credit_limit >= 0),
    CONSTRAINT CHK_dim_customers_account_tier CHECK (account_tier IN ('Gold', 'Silver', 'Bronze'))
);
GO

CREATE TABLE dim_products (
    product_id INT IDENTITY(1,1) NOT NULL,
    product_sku VARCHAR(50) NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    stock_level INT NOT NULL,
    product_status VARCHAR(50) NOT NULL DEFAULT 'Active',
    product_type VARCHAR(50) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    unit_cost DECIMAL(18,2) NOT NULL,
    list_price DECIMAL(18,2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NULL,
    category_id INT NOT NULL,
    CONSTRAINT PK_dim_products PRIMARY KEY (product_id),
    CONSTRAINT UQ_dim_products_product_sku UNIQUE (product_sku),
    CONSTRAINT FK_dim_products_category
        FOREIGN KEY (category_id) REFERENCES dim_categories(category_id),
    CONSTRAINT CHK_dim_products_stock_level CHECK (stock_level >= 0),
    CONSTRAINT CHK_dim_products_unit_cost CHECK (unit_cost > 0),
    CONSTRAINT CHK_dim_products_list_price CHECK (list_price > 0),
    CONSTRAINT CHK_dim_products_valid_dates CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
GO


  -- FACT TABLES


CREATE TABLE fact_sales_orders (
    order_id INT IDENTITY(1,1) NOT NULL,
    order_status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    payment_terms VARCHAR(50) NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    sales_org VARCHAR(50) NOT NULL,
    distribution_channel VARCHAR(50) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    customer_id INT NOT NULL,
    sales_rep_id INT NOT NULL,
    order_date_id INT NOT NULL,
    ship_date_id INT NULL,
    CONSTRAINT PK_fact_sales_orders PRIMARY KEY (order_id),
    CONSTRAINT FK_fact_sales_orders_customer
        FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    CONSTRAINT FK_fact_sales_orders_sales_rep
        FOREIGN KEY (sales_rep_id) REFERENCES dim_sales_reps(sales_rep_id),
    CONSTRAINT FK_fact_sales_orders_order_date
        FOREIGN KEY (order_date_id) REFERENCES dim_date(date_id),
    CONSTRAINT FK_fact_sales_orders_ship_date
        FOREIGN KEY (ship_date_id) REFERENCES dim_date(date_id)
);
GO

CREATE TABLE fact_order_line_items (
    line_item_id INT IDENTITY(1,1) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(18,2) NOT NULL,
    discount DECIMAL(5,4) NOT NULL DEFAULT 0,
    gross_amount DECIMAL(18,2) NOT NULL,
    net_amount DECIMAL(18,2) NOT NULL,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    date_id INT NOT NULL,
    CONSTRAINT PK_fact_order_line_items PRIMARY KEY (line_item_id),
    CONSTRAINT CHK_fact_order_line_items_quantity CHECK (quantity > 0),
    CONSTRAINT CHK_fact_order_line_items_unit_price CHECK (unit_price > 0),
    CONSTRAINT CHK_fact_order_line_items_discount CHECK (discount >= 0 AND discount <= 1),
    CONSTRAINT CHK_fact_order_line_items_gross_amount CHECK (gross_amount >= 0),
    CONSTRAINT CHK_fact_order_line_items_net_amount CHECK (net_amount >= 0),
    CONSTRAINT FK_fact_order_line_items_order
        FOREIGN KEY (order_id) REFERENCES fact_sales_orders(order_id),
    CONSTRAINT FK_fact_order_line_items_product
        FOREIGN KEY (product_id) REFERENCES dim_products(product_id),
    CONSTRAINT FK_fact_order_line_items_date
        FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
);
GO

CREATE TABLE fact_returns (
    return_id INT IDENTITY(1,1) NOT NULL,
    return_status VARCHAR(50) NOT NULL DEFAULT 'Open',
    return_quantity INT NOT NULL,
    credit_amount DECIMAL(18,2) NOT NULL,
    return_reason VARCHAR(100) NOT NULL,
    line_item_id INT NOT NULL,
    date_id INT NOT NULL,
    CONSTRAINT PK_fact_returns PRIMARY KEY (return_id),
    CONSTRAINT CHK_fact_returns_return_quantity CHECK (return_quantity > 0),
    CONSTRAINT CHK_fact_returns_credit_amount CHECK (credit_amount >= 0),
    CONSTRAINT FK_fact_returns_line_item
        FOREIGN KEY (line_item_id) REFERENCES fact_order_line_items(line_item_id),
    CONSTRAINT FK_fact_returns_date
        FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
);
GO

CREATE TABLE fact_quotas (
    quota_id INT IDENTITY(1,1) NOT NULL,
    quota_amount DECIMAL(18,2) NOT NULL,
    sales_rep_id INT NOT NULL,
    date_id INT NOT NULL,
    CONSTRAINT PK_fact_quotas PRIMARY KEY (quota_id),
    CONSTRAINT CHK_fact_quotas_quota_amount CHECK (quota_amount >= 0),
    CONSTRAINT FK_fact_quotas_sales_rep
        FOREIGN KEY (sales_rep_id) REFERENCES dim_sales_reps(sales_rep_id),
    CONSTRAINT FK_fact_quotas_date
        FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
);
GO


  -- BRIDGE / MAPPING TABLES
  
CREATE TABLE dbo.rep_customer_assignments (
    sales_rep_id INT NOT NULL,
    customer_id INT NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NULL,
    is_active BIT NOT NULL DEFAULT 1,

    CONSTRAINT PK_rep_customer_assignments 
        PRIMARY KEY (sales_rep_id, customer_id),

    CONSTRAINT FK_rep_customer_assignments_sales_rep
        FOREIGN KEY (sales_rep_id) REFERENCES dbo.dim_sales_reps(sales_rep_id),

    CONSTRAINT FK_rep_customer_assignments_customer
        FOREIGN KEY (customer_id) REFERENCES dbo.dim_customers(customer_id),

    CONSTRAINT CHK_rep_customer_assignments_dates
        CHECK (valid_to IS NULL OR valid_to >= valid_from)

);
GO

CREATE TABLE product_promotions (
    promotion_id INT IDENTITY(1,1) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NULL,
    discount_rate DECIMAL(5,4) NOT NULL,
    product_id INT NOT NULL,
    CONSTRAINT PK_product_promotions PRIMARY KEY (promotion_id),
    CONSTRAINT CHK_product_promotions_discount_rate
        CHECK (discount_rate >= 0 AND discount_rate <= 1),
    CONSTRAINT CHK_product_promotions_valid_dates
        CHECK (valid_to IS NULL OR valid_to >= valid_from),
    CONSTRAINT FK_product_promotions_product
        FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
);
GO


SELECT * FROM rep_customer_assignments;
SELECT * FROM dim_date;
