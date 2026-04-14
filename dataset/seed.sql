--DML: Seeding data

USE NordaTradeDB;
GO

SET NOCOUNT ON;
GO

/* =========================================
   CLEAN ALL DATA
   ========================================= */
DELETE FROM product_promotions;
DELETE FROM rep_customer_assignments;
DELETE FROM fact_quotas;
DELETE FROM fact_returns;
DELETE FROM fact_order_line_items;
DELETE FROM fact_sales_orders;
DELETE FROM dim_products;
DELETE FROM dim_customers;
DELETE FROM dim_sales_reps;
DELETE FROM dim_date;
DELETE FROM dim_categories;
DELETE FROM dim_regions;
GO

DBCC CHECKIDENT ('product_promotions', RESEED, 0);
DBCC CHECKIDENT ('rep_customer_assignments', RESEED, 0);
DBCC CHECKIDENT ('fact_quotas', RESEED, 0);
DBCC CHECKIDENT ('fact_returns', RESEED, 0);
DBCC CHECKIDENT ('fact_order_line_items', RESEED, 0);
DBCC CHECKIDENT ('fact_sales_orders', RESEED, 0);
DBCC CHECKIDENT ('dim_products', RESEED, 0);
DBCC CHECKIDENT ('dim_customers', RESEED, 0);
DBCC CHECKIDENT ('dim_sales_reps', RESEED, 0);
DBCC CHECKIDENT ('dim_date', RESEED, 0);
DBCC CHECKIDENT ('dim_categories', RESEED, 0);
DBCC CHECKIDENT ('dim_regions', RESEED, 0);
GO

/* =========================================
   1) dim_regions 
   ========================================= */
INSERT INTO dim_regions (country_name, region_name, territory_name)
VALUES
('Germany', 'Bavaria', 'Munich Territory'),
('Germany', 'Hesse', 'Frankfurt Territory'),
('Germany', 'Berlin', 'Berlin Territory'),
('Germany', 'North Rhine-Westphalia', 'Cologne Territory'),

('France', 'Ile-de-France', 'Paris Territory'),
('France', 'Auvergne-Rhone-Alpes', 'Lyon Territory'),
('France', 'Provence-Alpes-Cote d''Azur', 'Marseille Territory'),
('France', 'Nouvelle-Aquitaine', 'Bordeaux Territory'),

('Austria', 'Vienna', 'Vienna Territory'),
('Austria', 'Styria', 'Graz Territory'),
('Austria', 'Upper Austria', 'Linz Territory'),
('Austria', 'Salzburg', 'Salzburg Territory'),

('Switzerland', 'Zurich', 'Zurich Territory'),
('Switzerland', 'Geneva', 'Geneva Territory'),
('Switzerland', 'Basel-Stadt', 'Basel Territory'),
('Switzerland', 'Bern', 'Bern Territory'),

('Netherlands', 'North Holland', 'Amsterdam Territory'),
('Netherlands', 'South Holland', 'Rotterdam Territory'),
('Netherlands', 'Utrecht', 'Utrecht Territory'),
('Netherlands', 'North Brabant', 'Eindhoven Territory');
GO

/* =========================================
   2) dim_categories 
   ========================================= */
INSERT INTO dim_categories (category_name, segment_name, parent_category_id)
VALUES
('Machinery', 'Industrial Equipment', NULL),
('Safety Equipment', 'Industrial Equipment', NULL),
('Industrial Tools', 'Industrial Equipment', NULL),
('Pumps & Compressors', 'Industrial Equipment', NULL),
('Material Handling', 'Industrial Equipment', NULL),
('Spare Parts', 'Industrial Equipment', NULL),

('Paper Products', 'Office Supplies', NULL),
('Writing Instruments', 'Office Supplies', NULL),
('Office Furniture', 'Office Supplies', NULL),
('Printing Supplies', 'Office Supplies', NULL),
('Desk Accessories', 'Office Supplies', NULL),
('Storage & Filing', 'Office Supplies', NULL),

('Laptops', 'Technology Hardware', NULL),
('Monitors', 'Technology Hardware', NULL),
('Accessories', 'Technology Hardware', NULL),
('Keyboards', 'Technology Hardware', NULL),
('Networking Devices', 'Technology Hardware', NULL),
('Docking Solutions', 'Technology Hardware', NULL);
GO

/* =========================================
   3) dim_date 
   ========================================= */
DECLARE @StartDate DATE = '2021-01-01';
DECLARE @EndDate   DATE = CAST(GETDATE() AS DATE);

;WITH DateSeries AS
(
    SELECT @StartDate AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM DateSeries
    WHERE full_date < @EndDate
)
INSERT INTO dim_date
(
    full_date, year, quarter, month, month_name,
    week_number, day_of_week, day_name, is_business_day
)
SELECT
    full_date,
    YEAR(full_date),
    DATEPART(QUARTER, full_date),
    MONTH(full_date),
    DATENAME(MONTH, full_date),
    DATEPART(ISO_WEEK, full_date),
    CASE
        WHEN DATEPART(WEEKDAY, full_date) = 1 THEN 7
        ELSE DATEPART(WEEKDAY, full_date) - 1
    END,
    DATENAME(WEEKDAY, full_date),
    CASE
        WHEN DATENAME(WEEKDAY, full_date) IN ('Saturday', 'Sunday') THEN 0
        ELSE 1
    END
FROM DateSeries
OPTION (MAXRECURSION 2500);
GO

/* =========================================
   4) dim_sales_reps 
   ========================================= */
;WITH nums AS
(
    SELECT TOP (50) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
),
regions AS
(
    SELECT
        region_id,
        ROW_NUMBER() OVER (ORDER BY region_id) AS rn
    FROM dbo.dim_regions
)
INSERT INTO dbo.dim_sales_reps
(
    employee_code, rep_name, hire_date, job_title,
    sales_rep_status, is_active, valid_from, valid_to, region_id
)
SELECT
    CONCAT('REP', RIGHT('000' + CAST(n.n AS VARCHAR(3)), 3)),
    CONCAT(
        CHOOSE(((n.n - 1) % 10) + 1,
            'Anna', 'Lukas', 'Sophie', 'Julien', 'Eva',
            'Markus', 'Noah', 'Claire', 'Daan', 'Femke'
        ),
        ' ',
        CHOOSE((((n.n - 1) / 10) % 10) + 1,
            'Keller', 'Weber', 'Martin', 'Bernard', 'Gruber',
            'Hofer', 'Meier', 'Dubois', 'Visser', 'Jansen'
        )
    ),
    DATEADD(DAY, -(n.n * 30), CAST(GETDATE() AS DATE)),
    CHOOSE(((n.n - 1) % 4) + 1,
        'Sales Representative',
        'Senior Sales Representative',
        'Account Executive',
        'Key Account Manager'
    ),
    'Active',
    1,
    DATEADD(DAY, -(n.n * 30), CAST(GETDATE() AS DATE)),
    NULL,
    r.region_id
FROM nums n
JOIN regions r
    ON r.rn = ((n.n - 1) % 20) + 1;
GO

/* =========================================
   5) dim_customers 
   ========================================= */
;WITH nums AS
(
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
regions AS
(
    SELECT
        region_id,
        ROW_NUMBER() OVER (ORDER BY region_id) AS rn
    FROM dbo.dim_regions
),
base AS
(
    -- marrim max customer_code ekzistues
    SELECT ISNULL(MAX(CAST(SUBSTRING(customer_code,5,10) AS INT)),0) AS max_code
    FROM dbo.dim_customers
)
INSERT INTO dbo.dim_customers
(
    customer_name, 
    customer_type, customer_group, customer_status, account_tier,
    credit_limit, billing_address, is_active, customer_code, region_id
)
SELECT
    
    CONCAT(fn.first_name, ' ', ln.last_name),

    CHOOSE(((n.n - 1) % 3) + 1, 'Corporate', 'SME', 'Enterprise'),
    CHOOSE(((n.n - 1) % 4) + 1, 'Group A', 'Group B', 'Group C', 'Group D'),
    CHOOSE(((n.n - 1) % 3) + 1, 'Active', 'Inactive', 'Prospect'),
    CHOOSE(((n.n - 1) % 3) + 1, 'Gold', 'Silver', 'Bronze'),

    (ABS(CHECKSUM(NEWID())) % 100000) + 1000,

    CONCAT('Street ', n.n, ', City ', n.n),

    1,

    -- UNIQUE CUSTOMER CODE (fix)
    CONCAT('CUST', FORMAT(b.max_code + n.n, '000')),

    r.region_id

FROM nums n
CROSS JOIN base b

-- FIRST NAME
CROSS APPLY (
    SELECT CHOOSE(ABS(CHECKSUM(NEWID())) % 15 + 1,
        'Liam','Noah','Oliver','Elijah','James',
        'William','Benjamin','Lucas','Henry','Alexander',
        'Emma','Olivia','Ava','Sophia','Isabella'
    ) AS first_name
) fn

-- LAST NAME
CROSS APPLY (
    SELECT CHOOSE(ABS(CHECKSUM(NEWID())) % 15 + 1,
        'Smith','Johnson','Williams','Brown','Jones',
        'Garcia','Miller','Davis','Rodriguez','Martinez',
        'Anderson','Taylor','Thomas','Hernandez','Moore'
    ) AS last_name
) ln

JOIN regions r
    ON ((n.n - 1) % (SELECT COUNT(*) FROM regions)) + 1 = r.rn;

/* =======================================
   6) dim_products
   ========================================= */
;WITH nums AS
(
    SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
),
categories AS
(
    SELECT
        category_id,
        ROW_NUMBER() OVER (ORDER BY category_id) AS rn
    FROM dbo.dim_categories
)
INSERT INTO dbo.dim_products
(
    product_sku, product_name, stock_level, product_status,
    product_type, brand, is_active, unit_cost, list_price,
    valid_from, valid_to, category_id
)
SELECT
    CONCAT('SKU', RIGHT('0000' + CAST(n.n AS VARCHAR(4)), 4)),
    CONCAT(
        CHOOSE(((n.n - 1) % 8) + 1,
            'Pro', 'Plus', 'Max', 'Core', 'Ultra', 'Smart', 'Prime', 'Elite'
        ),
        ' ',
        CHOOSE((((n.n - 1) / 8) % 8) + 1,
            'Press', 'Helmet', 'Paper', 'Pen', 'Laptop', 'Monitor', 'Dock', 'Router'
        ),
        ' ',
        CAST(n.n AS VARCHAR(10))
    ),
    20 + (n.n % 250),
    'Active',
    CHOOSE(((n.n - 1) % 6) + 1,
        'Industrial Machine', 'Protective Gear', 'Consumable',
        'Stationery', 'Laptop', 'Accessory'
    ),
    CHOOSE((((n.n - 1) / 6) % 6) + 1,
        'NordaTech', 'SafeGuard', 'OfficeCore', 'WriteLine', 'TechNova', 'Connectix'
    ),
    1,
    CAST(25 + (n.n * 4.25) AS DECIMAL(18,2)),
    CAST(
        CASE
            WHEN CHOOSE(((n.n - 1) % 8) + 1, 'Pro', 'Plus', 'Max', 'Core', 'Ultra', 'Smart', 'Prime', 'Elite')
                 IN ('Pro', 'Max')
            THEN (25 + (n.n * 4.25)) * 3.50
            ELSE (25 + (n.n * 4.25)) * 1.70
        END
        AS DECIMAL(18,2)
    ),
    '2021-01-01',
    NULL,
    c.category_id
FROM nums n
JOIN categories c
    ON c.rn = ((n.n - 1) % 18) + 1;
GO
/* =========================================
   7) rep_customer_assignments
   ========================================= */

-- 7a. Current active assignment for every customer
;WITH customers AS
(
    SELECT
        customer_id,
        ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
    FROM dbo.dim_customers
),
sales_reps AS
(
    SELECT
        sales_rep_id,
        ROW_NUMBER() OVER (ORDER BY sales_rep_id) AS rn
    FROM dbo.dim_sales_reps
),
rep_pool AS
(
    SELECT sales_rep_id, rn
    FROM sales_reps
    WHERE rn <= 45
)
INSERT INTO dbo.rep_customer_assignments
(
    sales_rep_id,
    customer_id,
    valid_from,
    valid_to,
    is_active
)
SELECT
    rp.sales_rep_id,
    c.customer_id,
    CAST('2022-01-01' AS DATE),
    NULL,
    1
FROM customers c
JOIN rep_pool rp
    ON rp.rn = ((c.rn - 1) % 45) + 1;
GO

-- 7b. Historical reassignment for a subset of customers
;WITH customers AS
(
    SELECT TOP (150)
        customer_id,
        ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
    FROM dbo.dim_customers
    ORDER BY customer_id
),
sales_reps AS
(
    SELECT
        sales_rep_id,
        ROW_NUMBER() OVER (ORDER BY sales_rep_id) AS rn
    FROM dbo.dim_sales_reps
)
INSERT INTO dbo.rep_customer_assignments
(
    sales_rep_id,
    customer_id,
    valid_from,
    valid_to,
    is_active
)
SELECT
    sr.sales_rep_id,
    c.customer_id,
    DATEADD(DAY, -365 - ((c.rn - 1) % 120), CAST('2022-01-01' AS DATE)),
    DATEADD(DAY, -1, CAST('2022-01-01' AS DATE)),
    0
FROM customers c
JOIN sales_reps sr
    ON sr.rn = CASE
                   WHEN ((c.rn - 1) % 50) + 6 <= 50 THEN ((c.rn - 1) % 50) + 6
                   ELSE (((c.rn - 1) % 50) + 6) - 50
               END;
GO
/* =========================================
   8) product_promotions
   ========================================= */

;WITH nums AS
(
    SELECT TOP (120) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO product_promotions
(
    valid_from,
    valid_to,
    discount_rate,
    product_id
)
SELECT
    DATEFROMPARTS(
        2022 + ((n - 1) % 4),
        (((n - 1) % 12) + 1),
        1
    ) AS valid_from,

    EOMONTH(
        DATEFROMPARTS(
            2022 + ((n - 1) % 4),
            (((n - 1) % 12) + 1),
            1
        )
    ) AS valid_to,

    CAST(
        CHOOSE(((n - 1) % 5) + 1, 0.05, 0.07, 0.10, 0.12, 0.15)
        AS DECIMAL(5,4)
    ) AS discount_rate,

    (((n - 1) * 3) % 200) + 1 AS product_id
FROM nums;
GO
/* =========================================
   9) fact_quotas 
   ========================================= */
;WITH reps AS
(
    SELECT sales_rep_id FROM dim_sales_reps
),
months_base AS
(
    SELECT DISTINCT
        DATEFROMPARTS(year, month, 1) AS month_start
    FROM dim_date
)
INSERT INTO fact_quotas
(
    quota_amount, sales_rep_id, date_id, quota_period
)
SELECT
    CAST(
        18000
        + (r.sales_rep_id * 120)
        + (MONTH(mb.month_start) * 150)
        + ((YEAR(mb.month_start) - 2021) * 500)
        AS DECIMAL(18,2)
    ),
    r.sales_rep_id,
    d.date_id,
    'Monthly'
FROM reps AS r
CROSS JOIN months_base AS mb
JOIN dim_date AS d
    ON d.full_date = mb.month_start;
GO

/* =========================================
   10) fact_sales_orders 
   ========================================= */

DECLARE @OrdersStartDate DATE = '2022-01-01';
DECLARE @OrdersEndDate   DATE = CAST(GETDATE() AS DATE);
DECLARE @OrderDaySpan    INT  = DATEDIFF(DAY, @OrdersStartDate, @OrdersEndDate);

;WITH nums AS
(
    SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
order_base AS
(
    SELECT
        n,
        ((n - 1) % 500) + 1 AS customer_id,
        DATEADD(DAY, (n - 1) % (@OrderDaySpan - 25), @OrdersStartDate) AS order_full_date
    FROM nums
),
assigned_rep AS
(
    SELECT
        ob.n,
        ob.customer_id,
        ob.order_full_date,
        rca.sales_rep_id AS assigned_sales_rep_id
    FROM order_base ob
    JOIN rep_customer_assignments rca
        ON rca.customer_id = ob.customer_id
       AND rca.is_active = 1
       AND ob.order_full_date >= rca.valid_from
       AND (rca.valid_to IS NULL OR ob.order_full_date <= rca.valid_to)
)
INSERT INTO fact_sales_orders
(
    order_status,
    payment_terms,
    document_type,
    sales_org,
    distribution_channel,
    customer_id,
    sales_rep_id,
    order_date_id,
    ship_date_id
)
SELECT
    CHOOSE(((ar.n - 1) % 5) + 1,
        'Pending', 'Confirmed', 'Partially Delivered', 'Delivered', 'Cancelled'
    ) AS order_status,

    CHOOSE(((ar.n - 1) % 4) + 1,
        'Net 30', 'Net 45', 'Net 60', 'Prepaid'
    ) AS payment_terms,

    'Sales Order' AS document_type,
    'NordaTrade EU' AS sales_org,
    CHOOSE(((ar.n - 1) % 2) + 1, 'Direct', 'Dealer') AS distribution_channel,
    ar.customer_id,

    CASE
        WHEN ar.n % 12 = 0
            THEN CASE
                    WHEN ar.assigned_sales_rep_id + 1 <= 50 THEN ar.assigned_sales_rep_id + 1
                    ELSE 1
                 END
        ELSE ar.assigned_sales_rep_id
    END AS sales_rep_id,

    od.date_id AS order_date_id,

    CASE
        WHEN CHOOSE(((ar.n - 1) % 5) + 1,
            'Pending', 'Confirmed', 'Partially Delivered', 'Delivered', 'Cancelled'
        ) IN ('Pending', 'Cancelled')
            THEN NULL
        ELSE sd.date_id
    END AS ship_date_id
FROM assigned_rep ar
JOIN dim_date od
    ON od.full_date = ar.order_full_date
LEFT JOIN dim_date sd
    ON sd.full_date = DATEADD(DAY, 5 + (ar.n % 20), ar.order_full_date);
GO
/* =========================================
   11) fact_order_line_items
   ========================================= */




;WITH order_base AS
(
    SELECT
        o.order_id,
        o.order_date_id,
        d.full_date AS order_full_date,
        ((o.order_id - 1) % 4) + 1 AS items_per_order
    FROM fact_sales_orders o
    JOIN dim_date d
        ON d.date_id = o.order_date_id
),
line_gen AS
(
    SELECT
        ob.order_id,
        ob.order_date_id,
        ob.order_full_date,
        v.line_no
    FROM order_base ob
    CROSS APPLY
    (
        VALUES (1), (2), (3), (4)
    ) v(line_no)
    WHERE v.line_no <= ob.items_per_order
),
line_products AS
(
    SELECT
        lg.order_id,
        lg.order_date_id,
        lg.order_full_date,
        lg.line_no,
        (((lg.order_id * 7) + (lg.line_no * 13)) % 200) + 1 AS product_id,
        ((lg.order_id + lg.line_no) % 5) + 1 AS quantity
    FROM line_gen lg
)
INSERT INTO fact_order_line_items
(
    quantity,
    unit_price,
    discount,
    gross_amount,
    net_amount,
    order_id,
    product_id,
    date_id
)
SELECT
    lp.quantity,

    CAST(p.list_price AS DECIMAL(18,2)) AS unit_price,

    CAST(
        COALESCE(
            pp.discount_rate,
            CASE
                WHEN (lp.order_id + lp.line_no) % 10 = 0 THEN 0.15
                WHEN (lp.order_id + lp.line_no) % 6 = 0 THEN 0.10
                WHEN (lp.order_id + lp.line_no) % 4 = 0 THEN 0.05
                ELSE 0.00
            END
        )
        AS DECIMAL(5,4)
    ) AS discount,

    CAST(lp.quantity * p.list_price AS DECIMAL(18,2)) AS gross_amount,

    CAST(
        (lp.quantity * p.list_price) *
        (
            1 - COALESCE(
                    pp.discount_rate,
                    CASE
                        WHEN (lp.order_id + lp.line_no) % 10 = 0 THEN 0.15
                        WHEN (lp.order_id + lp.line_no) % 6 = 0 THEN 0.10
                        WHEN (lp.order_id + lp.line_no) % 4 = 0 THEN 0.05
                        ELSE 0.00
                    END
                )
        )
        AS DECIMAL(18,2)
    ) AS net_amount,

    lp.order_id,
    lp.product_id,
    lp.order_date_id AS date_id
FROM line_products lp
JOIN dim_products p
    ON p.product_id = lp.product_id
OUTER APPLY
(
    SELECT TOP (1)
        pr.discount_rate
    FROM product_promotions pr
    WHERE pr.product_id = lp.product_id
      AND lp.order_full_date >= pr.valid_from
      AND (pr.valid_to IS NULL OR lp.order_full_date <= pr.valid_to)
    ORDER BY pr.valid_from DESC
) pp;
GO
/* =========================================
   12) fact_returns 
   ========================================= */

;WITH li AS
(
    SELECT TOP (500)
        f.line_item_id,
        f.quantity,
        f.unit_price,
        f.discount,
        f.net_amount,
        f.date_id,
        ROW_NUMBER() OVER (ORDER BY f.line_item_id) AS rn
    FROM fact_order_line_items AS f
    ORDER BY f.line_item_id
),
return_base AS
(
    SELECT
        li.line_item_id,
        li.quantity,
        li.unit_price,
        li.discount,
        li.net_amount,
        li.date_id,
        li.rn,
        CASE
            WHEN li.quantity = 1 THEN 1
            WHEN li.quantity = 2 THEN 1
            WHEN li.quantity = 3 THEN 1
            WHEN li.quantity >= 4 AND li.rn % 2 = 0 THEN 2
            ELSE 1
        END AS return_quantity
    FROM li
)
INSERT INTO fact_returns
(
    return_status,
    return_quantity,
    credit_amount,
    return_reason,
    line_item_id,
    date_id
)
SELECT
    'Open' AS return_status,

    rb.return_quantity,

    CAST(
        rb.return_quantity * rb.unit_price * (1 - rb.discount)
        AS DECIMAL(18,2)
    ) AS credit_amount,

    CHOOSE(((rb.rn - 1) % 5) + 1,
        'Damaged item',
        'Late delivery',
        'Wrong item delivered',
        'Customer changed mind',
        'Defective item'
    ) AS return_reason,

    rb.line_item_id,
    rb.date_id
FROM return_base rb;
GO


SELECT 'dim_regions' AS table_name, COUNT(*) AS row_count FROM dim_regions
UNION ALL SELECT 'dim_categories', COUNT(*) FROM dim_categories
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'dim_sales_reps', COUNT(*) FROM dim_sales_reps
UNION ALL SELECT 'dim_customers', COUNT(*) FROM dim_customers
UNION ALL SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL SELECT 'rep_customer_assignments', COUNT(*) FROM rep_customer_assignments
UNION ALL SELECT 'product_promotions', COUNT(*) FROM product_promotions
UNION ALL SELECT 'fact_quotas', COUNT(*) FROM fact_quotas
UNION ALL SELECT 'fact_sales_orders', COUNT(*) FROM fact_sales_orders
UNION ALL SELECT 'fact_order_line_items', COUNT(*) FROM fact_order_line_items
UNION ALL SELECT 'fact_returns', COUNT(*) FROM fact_returns;
GO


--  TEST: Verifying that customer_name contains exactly first name and last name (no invalid entries)

SELECT *
FROM dbo.dim_customers
WHERE 
    customer_name LIKE '% %'
    AND customer_name NOT LIKE ' %'
    AND customer_name NOT LIKE '% '
    AND LEN(LTRIM(RTRIM(customer_name))) 
        - LEN(REPLACE(LTRIM(RTRIM(customer_name)), ' ', '')) = 1;

