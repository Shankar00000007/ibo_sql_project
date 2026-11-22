# ibo_sql_project

1.  primary keys, using DROP TABLE IF EXISTS first.Investment Banking Operations SQL Project
    A PostgreSQL project that models the trade lifecycle of an investment bank: clients, securities, trades and settlements. It answers real operations questions such as failed settlements, KYC risk, late and pending trades, and duplicate trades.
    Database
    Four tables, linked with foreign keys:
    ◦ clients: 60 clients with type, country and KYC status
    ◦ securities: 15 securities across equity, bond, ETF, future and forward
    ◦ trades: 2,000 trades with side, quantity, price, counterparty and status
    ◦ settlements: 1,885 settlements with expected and actual dates, status and fail reason
    The data is deliberately messy (nulls, wrong capitals, extra spaces) so cleaning is part of the project.
    What I did
    1.  Setup: created tables with 
2.  Load and verify: imported CSV files and checked row counts with UNION ALL.
3.  Data quality: found unmatched trades with LEFT JOIN and IS NULL.
4.  Protection: added foreign keys, NOT NULL, CHECK rules and indexes, and proved an index with EXPLAIN.
5.  Cleaning: fixed client names with TRIM, INITCAP and REPLACE, and handled missing values with COALESCE.
6.  Analysis: 13 operations queries (below).
Analysis queries and SQL topics used
• Failed settlements by reason: GROUP BY, ORDER BY
• Failure rate per client: CTE, CASE WHEN, JOIN
• Monthly traded value with running total: date functions, window function
• Top clients by traded value: RANK, DENSE_RANK
• Duplicate trades: ROW_NUMBER with PARTITION BY
• Late settlements: date arithmetic, CASE WHEN
• Pending trades past due date: ageing buckets, CURRENT_DATE
• KYC risk: trades for clients with expired or pending KYC
• Clients with no trades: NOT EXISTS
• Top client per security: ROW_NUMBER with PARTITION BY
• Daily change in traded value: LAG
• Possible offsetting trades: self join
• Trade status summary: GROUP BY with a window total
Tools
PostgreSQL, pgAdmin 4.
Files
• ibo_sql_project.sql: all SQL code
• clients.csv, securities.csv, trades.csv, settlements.csv: the data
• ibo_project_structure.png: project flow
Author
Shankargouda Bharamareddy, aspiring Data Analyst and Investment Banking Operations professional, Bengaluru.
