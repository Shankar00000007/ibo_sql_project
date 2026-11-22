DROP TABLE IF EXISTS settlements;
DROP TABLE IF EXISTS trades;
DROP TABLE IF EXISTS securities;
DROP TABLE IF EXISTS clients;
---------------------------------------------------------------------------------------------------

CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    client_name VARCHAR(100),
    client_type VARCHAR(50),
    country VARCHAR(50),
    kyc_status VARCHAR(20),
    onboard_date DATE
);

CREATE TABLE securities (
    security_id INT PRIMARY KEY,
    symbol VARCHAR(30),
    asset_class VARCHAR(20),
    currency VARCHAR(10)
);


CREATE TABLE trades (
    trade_id INT PRIMARY KEY,
    trade_date DATE,
    client_id INT,
    security_id INT,
    side VARCHAR(4),
    quantity INT,
    price NUMERIC(12,2),
    counterparty VARCHAR(50),
    status VARCHAR(20)
);

CREATE TABLE settlements (
    settlement_id INT PRIMARY KEY,
    trade_id INT,
    expected_settle_date DATE,
    actual_settle_date DATE,
    settle_status VARCHAR(20),
    fail_reason VARCHAR(50)
);


-----------------------------
SELECT * FROM clients;
SELECT * FROM securities;
SELECT * FROM trades;
SELECT * FROM settlements;
-----------------------------



-----------------------------------------------------------------------------------------------
-- Counted rows in each table to confirm all data loaded correctly.
SELECT 'clients' AS table_name, COUNT(*) AS rows FROM clients
UNION ALL SELECT'securities', COUNT(*) FROM securities
UNION ALL SELECT'trades', COUNT(*) FROM trades
UNION ALL SELECT'settlements', COUNT(*) FROM settlements;
------------------------------------------------------------------------------------------------





----------------------------------------------------------------------------------------------
-- Checks each trade's client_id from the trades table against client_id in the clients table.
-- If its unmatched it will count.
SELECT COUNT(*) AS unmatched_client_id
FROM trades t
LEFT JOIN clients c ON  t.client_id = c.client_id
WHERE c.client_id IS NULL;

SELECT COUNT(*) AS unmatched_security_id
FROM trades t
LEFT JOIN securities s ON t.security_id = s.security_id        --checked security_id
WHERE s.security_id IS NULL;

SELECT COUNT(*) AS unmatched_trade_id
FROM settlements st
LEFT JOIN trades t ON st.trade_id = t.trade_id                 --checked trade_id
WHERE t.trade_id IS NULL;
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------





--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--foregin key(it connect 2 table row eg client_id of trades table and client_id of clients table and it locks it).but before we need to use check is there any missmatch in client_id if not then we can use foregien key)

--used foreign key for client_id between trades and clients table
ALTER TABLE trades
ADD CONSTRAINT fk_trades_client
FOREIGN KEY (client_id) REFERENCES clients (client_id);

--used foreign key for security_id between trades and securities
ALTER TABLE trades
ADD CONSTRAINT fk_trades_security
FOREIGN KEY (security_id) REFERENCES securities (security_id);

--used foreign key for trade_id between trades and settlements
ALTER TABLE settlements
ADD CONSTRAINT fk_settlements_trade
FOREIGN KEY (trade_id) REFERENCES trades (trade_id);
------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------
--THIS QUARY MAKES COLUMNS MANDATORY THEY CAN NEVER BE EMPTY
-- Why: a trade without a date, side, quantity, price or status is invalid.
ALTER TABLE trades ALTER COLUMN trade_date SET NOT NULL;
ALTER TABLE trades ALTER COLUMN client_id SET NOT NULL;
ALTER TABLE trades ALTER COLUMN security_id SET NOT NULL;
ALTER TABLE trades ALTER COLUMN side SET NOT NULL;
ALTER TABLE trades ALTER COLUMN quantity SET NOT NULL;
ALTER TABLE trades ALTER COLUMN price SET NOT NULL;
ALTER TABLE trades ALTER COLUMN status SET NOT NULL;

-- Adds CHECK rules: quantity and price must be above zero, side must be BUY or SELL.
-- Why: blocks nonsense values like negative quantity or a side typed wrongly.
ALTER TABLE trades ADD CONSTRAINT chk_trades_quantity CHECK (quantity > 0);
ALTER TABLE trades ADD CONSTRAINT chk_trades_price CHECK (price > 0);
ALTER TABLE trades ADD CONSTRAINT chk_trades_side CHECK (side IN ('BUY', 'SELL'));
------------------------------------------------------------------------------------------------

-- CLIENTS: make key columns mandatory.
-- Why: every client needs a name, a type and a KYC status for compliance.
ALTER TABLE clients ALTER COLUMN client_name SET NOT NULL;
ALTER TABLE clients ALTER COLUMN client_type SET NOT NULL;
ALTER TABLE clients ALTER COLUMN kyc_status SET NOT NULL;

-- CLIENTS: KYC status can only be one of three valid values.
-- Why: blocks typos like 'Aproved' that would break reports.
ALTER TABLE clients ADD CONSTRAINT chk_clients_kyc
CHECK (kyc_status IN ('Approved', 'Pending', 'Expired'));

---------------------------------------------------------------------------------
-- SECURITIES: make key columns mandatory.
-- Why: a security without a symbol, asset class or currency cannot be traded or priced.
ALTER TABLE securities ALTER COLUMN symbol SET NOT NULL;
ALTER TABLE securities ALTER COLUMN asset_class SET NOT NULL;
ALTER TABLE securities ALTER COLUMN currency SET NOT NULL;
---------------------------------------------------------------------

-- SETTLEMENTS: make key columns mandatory.
-- Why: every settlement must link to a trade, have an expected date and a status.
-- actual_settle_date and fail_reason stay nullable on purpose (pending trades have neither).
ALTER TABLE settlements ALTER COLUMN trade_id SET NOT NULL;
ALTER TABLE settlements ALTER COLUMN expected_settle_date SET NOT NULL;
ALTER TABLE settlements ALTER COLUMN settle_status SET NOT NULL;

-- SETTLEMENTS: settle status can only be one of three valid values.
-- Why: keeps status clean so failed and pending counts are reliable.
ALTER TABLE settlements ADD CONSTRAINT chk_settlements_status
CHECK (settle_status IN ('Settled', 'Failed', 'Pending'));
---------------------------------------------------------------------------------------------------------------------------------------------




------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
--create indexes in column we oftenn join or filter on.
--why : make joins and filters on those column fasters, like a books index page.
CREATE INDEX idk_trades_client ON trades (client_id);
CREATE INDEX idk_trades_security ON trades (security_id);
CREATE INDEX idk_trades_date ON  trades (trade_date);
CREATE INDEX idk_trades_status ON trades (status);
CREATE INDEX idk_settlements_trade ON settlements (trade_id);
------------------------------------------------------------------------------------




-------------------------------------------------------------------------------------------------------
-- Finds client names with extra spaces or inconsistent capital letters.
-- Why: INITCAP gives the standard form (Rahul), so any name that differs from it needs cleaning.
SELECT client_id, client_name, INITCAP(TRIM(client_name)) AS clean_name
FROM clients
WHERE client_name <> INITCAP(TRIM(client_name));


-- Fixes messy client names: removes extra spaces and standardises capital letters.
-- Why: SELECT only showed the problem; UPDATE actually corrects it. Expected: 7 rows updated.
UPDATE clients
SET client_name = INITCAP(TRIM(client_name))
WHERE client_name <> INITCAP(TRIM(client_name));

-- Replaces spaces with underscores in client names, so all follow the Client_007 style.
-- Why: INITCAP and TRIM cannot fix this; REPLACE swaps one character for another.
UPDATE clients
SET client_name = REPLACE(client_name, ' ', '_')
WHERE client_name LIKE '% %';

-- Checks for any client name that still contains a space.
-- Why: verifies the REPLACE worked. Expected: 0 rows.
SELECT client_id, client_name
FROM clients
WHERE client_name LIKE '% %';
-----------------------------------------------------------------------------------------------------------



-----------------------------------------------------------------------------------------------------------
-- Shows missing country as 'Unknown' and missing counterparty as 'Not assigned', read-time only.
-- Why: COALESCE replaces null when reading, so reports show a label and stored data stays unchanged.
SELECT t.trade_id, c.client_name,
       COALESCE(c.country, 'Unknown') AS country,
       COALESCE(t.counterparty, 'Not assigned') AS counterparty
FROM trades t
JOIN clients c ON t.client_id = c.client_id
ORDER BY t.trade_id
LIMIT 50;
----------------------------------------------------------------------------------------------------------------





-------------------------------------------------------------------------------------------------------------------------
-- Counts failed settlements by reason, with the most common reason first.
-- Why: operations teams need to know why trades fail, so they can fix the main causes.
SELECT fail_reason, COUNT(*) AS failed_count
FROM settlements
WHERE settle_status = 'Failed'
GROUP BY fail_reason
ORDER BY failed_count DESC;
----------------------------------------------------------------------------------------------------------------



----------------------------------------------------------------------------------------------------------------------
-- Failure rate per client: failed settlements / total settlements, as a percentage.
-- Why: rate is a fair comparison, since busy clients naturally have more failures.
-- Reads: CTE counts per client, CASE WHEN counts only Failed, join adds client names.
WITH client_settlements AS (
    SELECT t.client_id,
           COUNT(*) AS total_settlements,
           SUM(CASE WHEN s.settle_status = 'Failed' THEN 1 ELSE 0 END) AS failed_settlements
    FROM trades t
    JOIN settlements s ON t.trade_id = s.trade_id
    GROUP BY t.client_id
)
SELECT c.client_name,
       cs.total_settlements,
       cs.failed_settlements,
       ROUND(100.0 * cs.failed_settlements / cs.total_settlements, 1) AS failure_rate_pct
FROM client_settlements cs
JOIN clients c ON cs.client_id = c.client_id
ORDER BY failure_rate_pct DESC
LIMIT 10;
-----------------------------------------------------------------------------------------------------------------------



-----------------------------------------------------------------------------------------------------------------------
-- Monthly traded value (quantity x price) with a running total across months.
-- Why: shows how trading builds up over time. Uses tables: trades only.
-- Reads: group trades by month, sum the value, then add up month by month.
WITH monthly AS (
    SELECT DATE_TRUNC('month', trade_date)::DATE AS trade_month,
           SUM(quantity * price) AS monthly_value
    FROM trades
    WHERE status <> 'Cancelled'
    GROUP BY DATE_TRUNC('month', trade_date)
)
SELECT trade_month,
       monthly_value,
       SUM(monthly_value) OVER (ORDER BY trade_month) AS running_total
FROM monthly
ORDER BY trade_month;
----------------------------------------------------------------------------------------------------




-----------------------------------------------------------------------------------------------------
-- Ranks clients by total traded value and also shows how many trades each did.
-- Why: value shows size, trade count shows activity. Cancelled trades excluded.
-- Tables used: trades and clients.
WITH client_value AS (
    SELECT t.client_id,
           COUNT(*) AS trade_count,
           SUM(t.quantity * t.price) AS total_value
    FROM trades t
    WHERE t.status <> 'Cancelled'
    GROUP BY t.client_id
)
SELECT c.client_name,
       cv.trade_count,
       cv.total_value,
       RANK() OVER (ORDER BY cv.total_value DESC) AS rank_no,
       DENSE_RANK() OVER (ORDER BY cv.total_value DESC) AS dense_rank_no
FROM client_value cv
JOIN clients c ON cv.client_id = c.client_id
ORDER BY rank_no
LIMIT 10;
--------------------------------------------------------------------------------------------




-----------------------------------------------------------------------------------------------------
-- Finds duplicate trades: same date, client, security, side, quantity and price.
-- Why: a trade booked twice means double settlement. rn = 1 is the original, rn = 2 or more is a duplicate.
-- Table used: trades only.
WITH numbered AS (
    SELECT trade_id, trade_date, client_id, security_id, side, quantity, price,
           ROW_NUMBER() OVER (
               PARTITION BY trade_date, client_id, security_id, side, quantity, price
               ORDER BY trade_id
           ) AS rn
    FROM trades
)
SELECT *
FROM numbered
WHERE rn > 1
ORDER BY trade_date, trade_id;
------------------------------------------------------------------------------------------------------------



--------------------------------------------------------------------------------------------------------
-- Counts settled trades by delay: on time, 1 day late, or 2 or more days late.
-- Why: late settlements risk penalties, so operations tracks the delay pattern.
-- Tables used: settlements only. Delay = actual date minus expected date.
SELECT CASE
           WHEN actual_settle_date <= expected_settle_date THEN 'On time'
           WHEN actual_settle_date - expected_settle_date = 1 THEN '1 day late'
           ELSE '2+ days late'
       END AS delay_group,
       COUNT(*) AS settled_count
FROM settlements
WHERE settle_status = 'Settled'
GROUP BY delay_group
ORDER BY settled_count DESC;
------------------------------------------------------------------------------------------------------------




----------------------------------------------------------------------------------------------------------
-- Lists pending settlements already past their expected date, with how many days overdue.
-- Why: these trades should have settled; operations must chase them before they fail.
-- Tables used: settlements, trades and clients.
SELECT t.trade_id,
       c.client_name,
       s.expected_settle_date,
       CURRENT_DATE - s.expected_settle_date AS days_overdue,
       CASE
           WHEN CURRENT_DATE - s.expected_settle_date <= 7 THEN '1-7 days'
           WHEN CURRENT_DATE - s.expected_settle_date <= 30 THEN '8-30 days'
           ELSE '30+ days'
       END AS ageing_bucket
FROM settlements s
JOIN trades t ON s.trade_id = t.trade_id
JOIN clients c ON t.client_id = c.client_id
WHERE s.settle_status = 'Pending'
  AND s.expected_settle_date < CURRENT_DATE
ORDER BY days_overdue DESC
LIMIT 20;
-----------------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------
-- Counts trades and traded value for clients whose KYC is not Approved.
-- Why: trading for a client without valid KYC is a compliance breach, so these need review.
-- Tables used: trades and clients. Cancelled trades excluded.
SELECT c.kyc_status,
       COUNT(*) AS trade_count,
       SUM(t.quantity * t.price) AS traded_value
FROM trades t
JOIN clients c ON t.client_id = c.client_id
WHERE c.kyc_status <> 'Approved'
  AND t.status <> 'Cancelled'
GROUP BY c.kyc_status
ORDER BY trade_count DESC;
--------------------------------------------------------------------------------------------------------------




----------------------------------------------------------------------------------------------------------
-- Lists clients who have never placed a trade.
-- Why: dormant clients need follow-up by sales, or review by compliance.
-- Tables used: clients and trades. NOT EXISTS keeps a client only if no trade matches.
SELECT c.client_id, c.client_name, c.client_type, c.kyc_status
FROM clients c
WHERE NOT EXISTS (
    SELECT 1
    FROM trades t
    WHERE t.client_id = c.client_id
)
ORDER BY c.client_id;
--------------------------------------------------------------------------------------------------------------------




----------------------------------------------------------------------------------------------------------------------
-- Finds the top client by traded value for each security.
-- Why: shows key clients per product. ROW_NUMBER restarts for each security; rn = 1 is the top client.
-- Tables used: trades, securities and clients. Cancelled trades excluded.
WITH client_security AS (
    SELECT t.security_id,
           t.client_id,
           SUM(t.quantity * t.price) AS total_value,
           ROW_NUMBER() OVER (
               PARTITION BY t.security_id
               ORDER BY SUM(t.quantity * t.price) DESC
           ) AS rn
    FROM trades t
    WHERE t.status <> 'Cancelled'
    GROUP BY t.security_id, t.client_id
)
SELECT s.symbol,
       c.client_name,
       cs.total_value
FROM client_security cs
JOIN securities s ON cs.security_id = s.security_id
JOIN clients c ON cs.client_id = c.client_id
WHERE cs.rn = 1
ORDER BY s.symbol;
---------------------------------------------------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------------
-- Daily traded value with the previous day's value and the change between them.
-- Why: shows if trading is rising or falling, and spots sudden spikes or drops.
-- Table used: trades only. LAG looks at the previous day's row. Cancelled trades excluded.
WITH daily AS (
    SELECT trade_date,
           SUM(quantity * price) AS daily_value
    FROM trades
    WHERE status <> 'Cancelled'
    GROUP BY trade_date
)
SELECT trade_date,
       daily_value,
       LAG(daily_value) OVER (ORDER BY trade_date) AS previous_day_value,
       daily_value - LAG(daily_value) OVER (ORDER BY trade_date) AS change
FROM daily
ORDER BY trade_date
LIMIT 20;
---------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------------
-- Finds possible offsetting trades: same client, security and quantity, one BUY and one SELL.
-- Why: operations reviews these pairs, since they may cancel each other out or signal an error.
-- Table used: trades joined with itself (a = the BUY trade, b = the SELL trade).
SELECT a.trade_id AS buy_trade,
       b.trade_id AS sell_trade,
       a.client_id,
       a.security_id,
       a.quantity
FROM trades a
JOIN trades b
  ON a.client_id = b.client_id
 AND a.security_id = b.security_id
 AND a.quantity = b.quantity
WHERE a.side = 'BUY'
  AND b.side = 'SELL'
  AND a.status <> 'Cancelled'
  AND b.status <> 'Cancelled'
ORDER BY a.client_id, a.security_id
LIMIT 20;
---------------------------------------------------------------------------------------------------------------------------------




----------------------------------------------------------------------------------------------------------------------------------
-- Trade status summary: count, total value and percentage share of all trades per status.
-- Why: a daily snapshot for operations; shows how many trades are settled, pending, failed, etc.
-- Table used: trades only. SUM(COUNT(*)) OVER () gives the grand total for the percentage.
SELECT status,
       COUNT(*) AS trade_count,
       SUM(quantity * price) AS total_value,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_trades
FROM trades
GROUP BY status
ORDER BY trade_count DESC;









