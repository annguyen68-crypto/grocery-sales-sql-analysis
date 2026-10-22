/* ============================================================
   01_cleaning/01_overview.sql  (MySQL)
   Database setup and checks that cover all 7 tables:
   row counts after import and column data types.
   Each check follows: query -> Result -> Decision
   ============================================================ */

CREATE DATABASE IF NOT EXISTS fmcg_project;
USE fmcg_project;

/* ------------------------------------------------------------
   Columns in scope for the analysis (only these are checked):
   sales.SalesID, sales.SalesPersonID, sales.CustomerID, sales.ProductID,
   sales.Quantity, sales.Discount, sales.TotalPrice, sales.SalesDate,
   sales.TransactionNumber
   products.ProductID, products.ProductName, products.Price,
   products.CategoryID, products.Class
   categories.CategoryID, categories.CategoryName
   customers.CustomerID, customers.CityID
   cities.CityID, cities.CityName, cities.CountryID
   countries.CountryID, countries.CountryName
   employees.EmployeeID, employees.FirstName, employees.LastName
   ------------------------------------------------------------ */


/* ------------------------------------------------------------
   1. Row counts after import
   ------------------------------------------------------------ */
SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL SELECT 'countries', COUNT(*) FROM countries
UNION ALL SELECT 'cities',    COUNT(*) FROM cities
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'products',  COUNT(*) FROM products
UNION ALL SELECT 'sales',     COUNT(*) FROM sales;
-- Result: categories 11; countries 206; cities 96; customers 98,759;
--   employees 23; products 452; sales 6,758,125.
-- Decision: Row counts match the source on Kaggle; the import is complete.


/* ------------------------------------------------------------
   2. Column data types vs Data Dictionary
   ------------------------------------------------------------ */
SELECT
      TABLE_NAME
    , COLUMN_NAME
    , DATA_TYPE
    , CASE
        WHEN DATA_TYPE IN ('varchar', 'char', 'text', 'mediumtext', 'longtext') THEN 'check blanks'
        ELSE 'check NULL only'
      END AS check_note
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'fmcg_project'
ORDER BY TABLE_NAME, ORDINAL_POSITION;
-- Result: Text columns in scope are varchar: sales.SalesDate, sales.TransactionNumber,
--   products.ProductName, products.Class, categories.CategoryName, cities.CityName,
--   countries.CountryName, employees.FirstName, employees.LastName.
--   SalesDate was imported as varchar (expected DATETIME); Price and Discount as double.
-- Decision:
--   In each table file, check text columns for NULL and fake blanks ('', spaces, 'NULL' text);
--   check other columns for NULL only.
--   Convert SalesDate to DATETIME in the clean view (10_v_sales_clean.sql).
--   Data Dictionary types are not followed (Price DECIMAL(4,0) would round prices to 0).
