# Phase 7 Optimization Package

## Scope
This document covers the Week 3 Phase 7 deliverables:

- 33. Index strategy
- 34. Slow-query audit
- 35. Data consistency report
- 36. View materialization analysis
- 37. Production checklist

Supporting SQL artifacts:

- `scripts/ddl/phase7_performance_indexes.sql`
- `scripts/ddl/phase7_performance_indexes_rollback.sql`
- `scripts/queries/performance/ReportingEngineerPhase7AuditQueries.sql`
- `scripts/queries/reporting_layer/ReportingEngineerPhase6Rollback.sql`

## Assumed Data Volume
Based on the current seed script:

- `dim_customers`: 500 rows
- `dim_products`: 200 rows
- `dim_sales_reps`: 50 rows
- `fact_sales_orders`: 5,000 rows
- `fact_order_line_items`: around 12,500 rows
- `fact_returns`: around 500 rows
- `fact_quotas`: monthly quota rows for every rep across the seeded calendar

The system is still small, but Phase 7 is about proving production thinking early: selective indexing, plan-aware query design, consistency controls, and clear release gates.

## Validation Status
- The repo deliverables are complete: index script, audit runner, and written analysis are present.
- Actual execution plans, logical reads, and elapsed time should be captured from the local SSMS session used for submission, because that evidence is environment-specific.
- The recommended live order is: DDL, seed, Phase 6 views, smoke test, Phase 7 indexes, then the 5 audit queries with Actual Execution Plan enabled.

## 33. Index Strategy
### Schema-Wide Strategy By Table
| Table | Workload Pattern | Strategy | Reasoning |
| --- | --- | --- | --- |
| `dim_regions` | Small lookup dimension joined by `region_id` | Keep existing PK/clustered access only | Small cardinality and low update cost do not justify extra secondary indexes yet |
| `dim_categories` | Small lookup dimension joined by `category_id` | Keep existing PK/clustered access only | Category rows are tiny and usually reached through `dim_products` |
| `dim_date` | Shared date lookup by `date_id` | Keep existing PK/clustered access only | Queries join on `date_id`; current size does not justify extra secondary indexes |
| `dim_sales_reps` | Joined by `sales_rep_id`; filtered/grouped by region | Add regional support index | Helps rep ranking and scorecard workloads |
| `dim_customers` | Joined by `customer_id`; rolled up by region and customer segment | Add regional support index | Helps geography-driven reporting and customer joins |
| `dim_products` | Joined by `product_id`; grouped by category | Add category support index | Helps product performance and category margin analysis |
| `fact_sales_orders` | Customer, rep, date, and status filtering | Add multiple selective nonclustered indexes | Core driver for customer, rep, and executive reporting |
| `fact_order_line_items` | Heavy joins from orders to lines; product and date aggregation | Add multiple nonclustered indexes | Largest fact surface for revenue and product metrics |
| `fact_returns` | Return-to-line joins and returns analysis by time/reason | Add targeted nonclustered indexes | Supports both detail lookup and grouped return reporting |
| `fact_quotas` | Rep/date filtering and monthly quota rollups | Add targeted nonclustered indexes | Needed for attainment and executive quota analysis |
| `rep_customer_assignments` | Current-owner lookup and time-window validation | Add temporal/customer and temporal/rep indexes | Supports current assignment logic and mismatch analysis |
| `product_promotions` | Product/time-window lookups | Add product-window index | Helps promotion lookups if pricing logic grows later |

### Proposed Secondary Indexes
| Index | Table | Key Columns | Query Pattern Supported | Estimated Selectivity | Write Trade-off |
| --- | --- | --- | --- | --- | --- |
| `IX_fact_sales_orders_customer_order_date` | `fact_sales_orders` | `(customer_id, order_date_id)` | Customer 360, customer order history | High | Moderate insert overhead |
| `IX_fact_sales_orders_sales_rep_order_date` | `fact_sales_orders` | `(sales_rep_id, order_date_id)` | Rep scorecards, executive summary | High | Moderate insert overhead |
| `IX_fact_sales_orders_order_status_order_date` | `fact_sales_orders` | `(order_status, order_date_id)` | Excluding cancelled orders in reporting | Medium | Low to moderate |
| `IX_fact_order_line_items_order` | `fact_order_line_items` | `(order_id)` | Order-to-line joins and line aggregation | Very high | Moderate |
| `IX_fact_order_line_items_product_date` | `fact_order_line_items` | `(product_id, date_id)` | Product reporting by time | High | Moderate |
| `IX_fact_order_line_items_date_order` | `fact_order_line_items` | `(date_id, order_id)` | Time-series reporting | Medium to high | Moderate |
| `IX_fact_returns_line_item` | `fact_returns` | `(line_item_id)` | Return-to-line enrichment | Very high | Low |
| `IX_fact_returns_date_reason` | `fact_returns` | `(date_id, return_reason)` | Returns analysis by period and reason | Medium | Low |
| `IX_fact_quotas_sales_rep_date_period` | `fact_quotas` | `(sales_rep_id, date_id, quota_period)` | Rep quota rollups | High | Low to moderate |
| `IX_fact_quotas_date_period` | `fact_quotas` | `(date_id, quota_period)` | Executive quota rollups by month | Medium | Low to moderate |
| `IX_rep_customer_assignments_customer_active_window` | `rep_customer_assignments` | `(customer_id, is_active, valid_from, valid_to)` | Current assignment lookup | High | Low |
| `IX_rep_customer_assignments_sales_rep_active_window` | `rep_customer_assignments` | `(sales_rep_id, is_active, valid_from, valid_to)` | Rep ownership analysis | High | Low |
| `IX_dim_customers_region` | `dim_customers` | `(region_id)` | Geography reporting and customer joins | Medium | Low |
| `IX_dim_sales_reps_region` | `dim_sales_reps` | `(region_id)` | Regional rep ranking | Medium | Low |
| `IX_dim_products_category` | `dim_products` | `(category_id)` | Product and margin by category | Medium | Low |
| `IX_product_promotions_product_window` | `product_promotions` | `(product_id, valid_from, valid_to)` | Promotion lookup by product and time window | High | Low |

The package proposes 16 distinct indexes, which exceeds the minimum requirement of 15.

## 34. Slow Query Audit
Audit runner:

- `scripts/queries/performance/ReportingEngineerPhase7AuditQueries.sql`

Live capture procedure:

1. Open SSMS with Actual Execution Plan enabled.
2. Run each audit query block separately.
3. Save the actual plan or screenshot for each query.
4. Record logical reads, CPU time, and elapsed time from the Messages tab.
5. Compare behavior before and after the Phase 7 index script if you want a stronger optimization story.

### Audited Queries
| Audit Query | Source | Why It Is Complex | Expensive Nodes To Validate In Actual Plan | Structural Improvement To Defend |
| --- | --- | --- | --- | --- |
| Customer Delivery Exception Report | `ReportingEngineerPhase4Queries.sql` | Uses repeated scalar subqueries plus an aggregated order-value subquery and final sort | Repeated key lookups, aggregate on line items, sort on computed delay | Replace scalar subqueries with joins and keep order-value aggregation reusable |
| Returns Operations Detail Report | `ReportingEngineerPhase4Queries.sql` | Uses scalar lookups for date, customer, and category on top of multi-table joins | Nested lookups and final sort | Rewrite to explicit joins or route through `vw_base_return_detail` |
| Customer 360 Candidate Dataset | `ReportingEngineerAdvanceQueries.sql` | Multiple CTEs, aggregates, return enrichment, assignment ranking, and country ranking | Hash aggregates, window sort, assignment ranking sort | Keep customer, order, and assignment access paths indexed; materialize later if heavily reused |
| Monthly Country Trend Dataset | `ReportingEngineerAdvanceQueries.sql` | Broad monthly aggregation followed by `LAG` and running total windows | Aggregate over line items plus window-function sort | Use time-oriented indexes and optionally promote repeated monthly summaries to a reusable layer |
| Rep-Customer Mismatch | `phase4_joins_multitable_logic.sql` | Temporal join over assignment windows plus dual sales-rep lookups | Join on date-range predicates, assignment scans, final sort | Support assignment window lookups with temporal indexes and keep date joins selective |

The fifth audit query is taken from the shared Phase 4 team query library because it is one of the heaviest reporting-relevant workloads involving temporal assignment logic.

## 35. Data Consistency Report
### Scenario 1: Order Header Inserts But Line Items Fail
- Failure mode: the order header is committed but one or more related line items are missing.
- Reporting impact: order counts increase while revenue and units do not, which breaks executive and customer metrics.
- Schema protection: foreign keys protect line items from referencing a missing order, but they do not prevent an order from existing without lines.
- Application handling: create order header and line items in one transaction and roll back the whole unit if any line insert fails.
- Operational check: run a daily exception query for orders with zero line items.

### Scenario 2: Return Quantity Exceeds Sold Quantity
- Failure mode: cumulative returns on a line item become greater than the quantity originally sold.
- Reporting impact: return-rate KPIs and credit-note reporting become inflated and misleading.
- Schema protection: foreign keys can guarantee the line item exists, but they do not guarantee quantity consistency.
- Application handling: validate cumulative returned quantity before insert or update, inside the same transaction that writes the return.
- Operational check: run a scheduled exception report for any line where `SUM(return_quantity) > sold_quantity`.

### Scenario 3: Overlapping Customer Assignment Windows
- Failure mode: the same customer has multiple assignments valid for the same date range.
- Reporting impact: customer ownership, rep scorecards, and mismatch audits become disputed.
- Schema protection: the table stores validity windows, but SQL Server does not natively prevent overlapping ranges here.
- Application handling: perform overlap checks inside the write transaction before inserting or updating assignments.
- Operational check: run a daily overlap report and block downstream scorecard publication until conflicts are resolved.

## 36. View Materialization Analysis
| View | Materialize? | Recommendation | Refresh Strategy | Staleness Tolerance |
| --- | --- | --- | --- | --- |
| `vw_sales_executive_summary` | Yes | Strong dashboard candidate because it aggregates revenue, profit, and quota and is likely to be reused often | Daily after ETL | Up to 24 hours |
| `vw_customer_360` | Yes | Good candidate because it combines customer joins, order aggregates, returns, assignment logic, and segmentation | Nightly after order, return, and assignment loads | Up to 24 hours |
| `vw_product_performance` | Yes | Good candidate for repeated merchandising and finance analysis | Nightly | Up to 24 hours |
| `vw_rep_performance_scorecard` | Yes | Good candidate because managers revisit rep attainment repeatedly within the same period | Daily or after quota refresh | Same business day |
| `vw_monthly_trend` | No for current scale | Keep as a normal view for now; the data volume is still small and the logic is understandable | Reassess when line-item volume grows materially | Real-time is acceptable |
| `vw_returns_analysis` | No for current scale | Keep as a normal view for now because returns volume is still limited | Reassess if returns volume or dashboard concurrency rises | Real-time is acceptable |

## Rollback Procedures
### Phase 7 Index Deployment Rollback
- Trigger the rollback if write latency increases materially after index deployment, if the audited queries regress instead of improving, or if the deployment window must be backed out for operational reasons.
- Use `scripts/ddl/phase7_performance_indexes_rollback.sql` to remove only the secondary indexes introduced by the Phase 7 package. The script is idempotent because every drop is guarded by an existence check.
- After index rollback, rerun the Phase 6 smoke test and at least the highest-priority audit queries to confirm the reporting layer still compiles and that query behavior has returned to the pre-index baseline.
- If the rollback is performed in production, capture the post-rollback execution evidence in the same place as the original audit evidence so the change history remains defensible.

### Phase 6 Reporting-Layer Release Rollback
- Trigger the rollback if any of the released reporting views fail to compile, return incorrect business totals, or break downstream consumers after deployment.
- Use `scripts/queries/reporting_layer/ReportingEngineerPhase6Rollback.sql` to remove the Phase 6 reporting views in reverse dependency order: Tier 3 final views first, Tier 2 summary views second, and Tier 1 base views last.
- After the rollback script finishes, redeploy the last approved reporting-layer version from source control if one exists. If no approved previous version is available, keep the reporting layer disabled and use the pre-release query library until the corrected view package is ready.
- Verification after reporting rollback should include confirming that the rollback script completed without dependency errors and that any restored reporting package passes `scripts/queries/reporting_layer/ReportingEngineerPhase6SmokeTest.sql`.

## 37. Production Checklist
- Confirm all primary keys, foreign keys, and check constraints in `ddl.sql` are present and enabled.
- Confirm `dim_date` covers the full operational and reporting time range.
- Confirm seed or production load finishes without orphaned fact rows.
- Confirm all Phase 6 views compile successfully in the target environment.
- Confirm the Phase 6 smoke test returns rows for all 6 final views.
- Confirm cancelled orders are excluded consistently from revenue-facing KPIs.
- Confirm return quantities do not exceed sold quantities.
- Confirm overlapping customer assignments are blocked or detected before reporting refresh.
- Confirm the Phase 7 index script is applied in the target environment.
- Confirm all 5 audit queries run with Actual Execution Plan enabled and their evidence is saved.
- Confirm logical reads, CPU time, and elapsed time are recorded for the audit queries.
- Confirm at least one structural improvement is documented for each audited query.
- Confirm report consumers have read-only access and no write permissions on reporting objects.
- Confirm deployment order is documented: database, DDL, seed/load, indexes, reporting views, verification.
- Confirm rollback steps exist for index deployment and reporting-layer release.
