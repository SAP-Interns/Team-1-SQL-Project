USE NordaTradeDB;
GO

/* =========================================
   REPORTING ENGINEER
   WEEK 3 - PHASE 6
   REPORTING LAYER ROLLBACK
   ========================================= */

/* Drop Tier 3 final views first */
DROP VIEW IF EXISTS dbo.vw_returns_analysis;
GO
DROP VIEW IF EXISTS dbo.vw_monthly_trend;
GO
DROP VIEW IF EXISTS dbo.vw_rep_performance_scorecard;
GO
DROP VIEW IF EXISTS dbo.vw_product_performance;
GO
DROP VIEW IF EXISTS dbo.vw_customer_360;
GO
DROP VIEW IF EXISTS dbo.vw_sales_executive_summary;
GO

/* Drop Tier 2 summary views after Tier 3 is removed */
DROP VIEW IF EXISTS dbo.vw_summary_returns_analysis;
GO
DROP VIEW IF EXISTS dbo.vw_summary_monthly_trend;
GO
DROP VIEW IF EXISTS dbo.vw_summary_rep_performance;
GO
DROP VIEW IF EXISTS dbo.vw_summary_product_performance;
GO
DROP VIEW IF EXISTS dbo.vw_summary_customer_360;
GO
DROP VIEW IF EXISTS dbo.vw_summary_sales_executive;
GO

/* Drop Tier 1 base views last */
DROP VIEW IF EXISTS dbo.vw_base_return_detail;
GO
DROP VIEW IF EXISTS dbo.vw_base_quota_detail;
GO
DROP VIEW IF EXISTS dbo.vw_base_order_line_detail;
GO
