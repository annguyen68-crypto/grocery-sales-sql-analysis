/* ============================================================
   01_cleaning/10_v_sales_clean.sql  (MySQL)
   Builds the clean view used by every analysis file, from the decisions
   in files 01-09, and summarises the cleaning.
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   Clean view
   Raw tables stay unchanged:
   - SalesDate converted to DATETIME, blanks -> NULL + flag (02_sales.sql, step 2)
   - revenue = Quantity * Price * (1 - Discount) (02_sales.sql, step 4)
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW v_sales_clean AS
SELECT
      s.SalesID
    , s.TransactionNumber
    , s.SalesPersonID
    , s.CustomerID
    , s.ProductID
    , s.Quantity
    , s.Discount
    , p.Price
    , CASE WHEN TRIM(s.SalesDate) IN ('', 'NULL') OR s.SalesDate IS NULL
           THEN NULL
           ELSE CAST(s.SalesDate AS DATETIME)
      END AS SalesDate
    , CASE WHEN TRIM(s.SalesDate) IN ('', 'NULL') OR s.SalesDate IS NULL
           THEN 0 ELSE 1
      END AS has_sales_date
    , ROUND(s.Quantity * p.Price, 2)                    AS gross_sales
    , ROUND(s.Quantity * p.Price * (1 - s.Discount), 2) AS net_sales
FROM sales s
JOIN products p ON s.ProductID = p.ProductID;

-- Checks on the view
SELECT COUNT(*) FROM v_sales_clean;                  -- 6,758,125 (no rows lost in the JOIN)
SELECT SUM(has_sales_date = 0) FROM v_sales_clean;   -- 67,526 (matches 02_sales.sql, step 2)


/* ------------------------------------------------------------
   Summary: rows before / after cleaning
   ------------------------------------------------------------
   Rows in  (raw sales):      6,758,125
   Rows out (v_sales_clean):  6,758,125  -- no rows deleted

   Issues found and how they were handled:
   - SalesDate stored as text, 67,526 missing values (~1.0%)
       -> converted to DATETIME; blanks set to NULL and flagged
          (has_sales_date = 0). Flagged rows are kept for totals
          and excluded only from time-based analysis.
   - TotalPrice = 0 in every row
       -> not used; revenue calculated in the view:
          gross_sales = Quantity * Price
          net_sales   = Quantity * Price * (1 - Discount)
   - 16 duplicate groups (all with missing SalesDate)
       -> kept; likely coincidental, not true duplicates.
   - Data Dictionary glossary lists 8 categories (Northwind sample),
     categories.csv has 11
       -> category names taken from categories.csv.
   - Data Dictionary types (e.g. Price DECIMAL(4,0)) would round
     prices to 0 -> not followed.

   Checks passed:
   - One row = one order (grain check)
   - No missing values in columns in scope except SalesDate; no duplicate IDs
   - All values in valid ranges (Quantity 1-25, Discount 0-0.2,
     Price 0.04-99.88)
   - 0 orphan rows in all foreign key checks
   - 7 primary keys + 7 foreign keys added

   Data covers 2018-01-01 to 2018-05-09 (May is a partial month).
   ------------------------------------------------------------ */
