/* ============================================================
   01_cleaning/04_customers.sql  (MySQL)
   Checks on the customers table: missing values and duplicate IDs.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Missing values
   ------------------------------------------------------------ */
SELECT
    COUNT(*) - COUNT(CustomerID) AS null_customer_id,
    COUNT(*) - COUNT(CityID)     AS null_city_id
FROM customers;
-- Result: 0 in both columns.
-- Decision: No action needed.


/* ------------------------------------------------------------
   2. Duplicate IDs
   ------------------------------------------------------------ */
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT CustomerID) AS distinct_ids
FROM customers;
-- Result: total_rows = distinct_ids (98,759): no duplicate IDs.
-- Decision: Safe to JOIN with sales; CustomerID can be the primary key.
