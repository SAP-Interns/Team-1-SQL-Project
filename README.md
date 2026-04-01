# Team-1-SQL-Project

Enterprise Sales Analytics System

**SAP BW/4HANA-Inspired SQL Capstone Project**

---

Overview

This project is a team-based SQL capstone designed to simulate a real-world **Enterprise Sales Analytics System**. It follows the architectural principles of **SAP BW/4HANA**, transforming raw transactional data into business-ready insights using SQL.

The system enables analysis of:

* Customer behavior and segmentation
* Sales performance and quotas
* Product profitability and trends
* Time-based revenue analysis

---

Business Context

The system is built for a fictional company:

**NordaTrade GmbH**
A European wholesale distributor operating across:

* Germany
* France
* Austria
* Switzerland
* Netherlands

The goal is to solve real business problems such as:

* Identifying at-risk customers
* Analyzing revenue trends
* Measuring sales rep performance
* Understanding product profitability

---

 Architecture (SAP BW/4HANA Style)

The project follows a layered architecture:

```
Raw Data → Transactional Layer → Analytical Layer → Reporting Layer
```

 Layers

* **Transactional Layer (PSA)**
  Normalized tables (3NF) storing raw business data

* **Analytical Layer (DSO / InfoCube)**
  Aggregations and transformations

* **Reporting Layer (BEx-style Views)**
  Business-ready SQL views for decision-making

---

Data Model

 Dimensions

* Customers
* Products
* Sales Representatives
* Categories
* Regions
* Date

 Facts

* Sales Orders
* Order Line Items
* Returns
* Quotas

 Bridge Tables

* Rep-Customer Assignments
* Product Promotions

---

 Key Features

*  Fully normalized schema (3NF)
*  SAP-style time-dependent data modeling
*  Advanced SQL (CTEs, window functions, subqueries)
*  KPI calculations (Revenue, Margin, Quotas, RFM)
*  Multi-layer reporting views
*  Performance optimization (indexes, execution plans)

---
  Key Analytics Implemented

* RFM Customer Segmentation
* Month-over-Month Revenue Trends
* Running Totals & Time-Series Analysis
* Sales Rep Ranking & Quota Attainment
* Product Performance & Return Rates

---

  Technologies Used

* SQL (PostgreSQL / SQL Server compatible)
* SAP BW/4HANA Modeling Concepts
* Git & GitHub

---

 Team Roles

* **Data Modeler** – Schema design, ERD, DDL
* **Query Engineer** – Core SQL queries & aggregations
* **Analytics Engineer** – Advanced SQL (CTEs, window functions)
* **Reporting Engineer** – Views, KPIs, optimization

---

 Project Structure

```
dataset /
diagrams /
docs /
scripts /
         ddl /
         dml /
         queries / 
```

---

 How to Run

---

In SQL Enviroments

---

 Deliverables

*  ERD Diagram
*  DDL Scripts
*  Query Library
*  Reporting Views
*  Optimization Report
*  Documentation Package

---

 Project Goal

To design a **production-ready analytical system** that:

* Transforms raw data into insights
* Supports business decision-making
* Follows real-world SAP data warehousing principles

---

 Final Note

This project is built to simulate a real consulting engagement.
Every design decision, query, and optimization is expected to be **justified, documented, and defensible**.

---

 Team 1

SQL Internship Capstone Project
Enterprise Data Engineering & Analytics

