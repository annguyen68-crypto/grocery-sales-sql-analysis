/* ============================================================
   01_cleaning/02_sales.sql  (MySQL)
   Checks on the sales table: grain, missing values, duplicates, value ranges.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Grain: what does one row represent?
   ------------------------------------------------------------ */
SELECT
    COUNT(*)                          AS total_rows,
    COUNT(DISTINCT TransactionNumber) AS distinct_transactions,
    COUNT(DISTINCT SalesID)           AS distinct_sales_ids
FROM sales;
-- Result: total_rows = distinct_transactions = distinct_sales_ids = 6,758,125.
--   Every row is a separate transaction with exactly one product; no duplicate SalesID.
-- Decision: Treat each row as one order (orders = COUNT(*)).
--   Products per order is always 1, so basket size is measured as units per order:
--   UPT = SUM(Quantity) / orders; AOV = gross sales / orders.


/* ------------------------------------------------------------
   2. Missing values
   2a. Real NULLs: COUNT(*) - COUNT(column)
   2b. Fake blanks in text columns: '', spaces only, or the text 'NULL'
   ------------------------------------------------------------ */
SELECT
    COUNT(*) - COUNT(SalesID)           AS null_sales_id,
    COUNT(*) - COUNT(SalesPersonID)     AS null_salesperson_id,
    COUNT(*) - COUNT(CustomerID)        AS null_customer_id,
    COUNT(*) - COUNT(ProductID)         AS null_product_id,
    COUNT(*) - COUNT(Quantity)          AS null_quantity,
    COUNT(*) - COUNT(Discount)          AS null_discount,
    COUNT(*) - COUNT(TotalPrice)        AS null_total_price,
    COUNT(*) - COUNT(SalesDate)         AS null_sales_date,
    COUNT(*) - COUNT(TransactionNumber) AS null_transaction_number
FROM sales;

SELECT
    SUM(CASE WHEN TRIM(SalesDate)         IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_sales_date,
    SUM(CASE WHEN TRIM(TransactionNumber) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_transaction_number
FROM sales;
-- Result (2a + 2b): SalesDate has 67,526 missing values (real NULL, blank or 'NULL' text),
--   about 1.0% of rows. All other columns: 0.
-- Decision: Keep these rows and flag them instead of deleting.
--   In the clean view: convert SalesDate to a real date (blanks become NULL)
--   and add a flag column has_sales_date = 1 / 0.
--   Use all rows for totals, products, customers, salespeople and geography;
--   exclude flagged rows only from time-based analysis (Scenario 1, 3.2, 4.3 and days sold in 4.1).


/* ------------------------------------------------------------
   3. Duplicate rows (all columns except SalesID and TransactionNumber)
   ------------------------------------------------------------ */
SELECT
      SalesPersonID
    , CustomerID
    , ProductID
    , Quantity
    , Discount
    , TotalPrice
    , SalesDate
    , COUNT(*) AS dup_count
FROM sales
GROUP BY SalesPersonID, CustomerID, ProductID, Quantity, Discount, TotalPrice, SalesDate
HAVING COUNT(*) > 1;
-- Result: 16 groups with dup_count = 2 (32 rows, 16 potential extras).
--   All 16 groups have a missing SalesDate; each row still has its own
--   TransactionNumber. No duplicates among rows with a valid SalesDate.
-- Decision: Not treated as true duplicates. Matches are likely coincidental
--   because the date is missing. Keep all rows (impact: 16 of 6,758,125 rows).


/* ------------------------------------------------------------
   4. Value ranges
   ------------------------------------------------------------ */
SELECT
      MIN(Quantity)   AS min_qty
    , MAX(Quantity)   AS max_qty
    , MIN(Discount)   AS min_discount
    , MAX(Discount)   AS max_discount
    , MIN(TotalPrice) AS min_totalprice
    , MAX(TotalPrice) AS max_totalprice
FROM sales;
-- Result: Quantity 1-25; Discount 0-0.2; TotalPrice = 0 in every row.
-- Decision: Quantity and Discount are valid.
--   TotalPrice is unusable (all zeros). Revenue is calculated in the
--   clean view as Quantity * Price * (1 - Discount), with Price from products.

SELECT
      MIN(SalesDate) AS min_salesdate
    , MAX(SalesDate) AS max_salesdate
FROM sales
WHERE TRIM(SalesDate) NOT IN ('', 'NULL');
-- Result: SalesDate ranges from 2018-01-01 to 2018-05-09 (excluding blank dates).
-- Decision: Data covers Jan-Apr 2018 in full, May 2018 only partially (9 days).
--   In time-based analysis, compare months by revenue per day, not monthly totals.
