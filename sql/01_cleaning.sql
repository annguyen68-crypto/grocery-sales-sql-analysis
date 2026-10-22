/* ============================================================
   01_cleaning.sql  (MySQL)
   Data quality checks on the Grocery Sales database.
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
   0. Row counts after import
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
-- Decision: Row counts match the Dataset table in README.md; the import is complete.


/* ------------------------------------------------------------
   1. Grain: what does one row in sales represent?
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
--   Noted in README (Data cleaning and Data limitations).


/* ------------------------------------------------------------
   1b. Column data types vs Data Dictionary
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
--   Step 2: check text columns in scope for NULL, '', spaces and 'NULL' text.
--   Step 8: convert SalesDate to DATETIME in the clean view.
--   Data Dictionary types are not followed (Price DECIMAL(4,0) would round prices to 0).


/* ------------------------------------------------------------
   2. Missing values in columns in scope
   2a. Real NULLs: COUNT(*) - COUNT(column) for every column in scope
   2b. Fake blanks in text columns: '', spaces only, or the text 'NULL'
   ------------------------------------------------------------ */

-- 2a. NULL counts per table
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
    COUNT(*) - COUNT(ProductID)   AS null_product_id,
    COUNT(*) - COUNT(ProductName) AS null_product_name,
    COUNT(*) - COUNT(Price)       AS null_price,
    COUNT(*) - COUNT(CategoryID)  AS null_category_id,
    COUNT(*) - COUNT(Class)       AS null_class
FROM products;

SELECT
    COUNT(*) - COUNT(CustomerID) AS null_customer_id,
    COUNT(*) - COUNT(CityID)     AS null_city_id
FROM customers;

SELECT
    COUNT(*) - COUNT(CityID)    AS null_city_id,
    COUNT(*) - COUNT(CityName)  AS null_city_name,
    COUNT(*) - COUNT(CountryID) AS null_country_id
FROM cities;

SELECT
    COUNT(*) - COUNT(CategoryID)   AS null_category_id,
    COUNT(*) - COUNT(CategoryName) AS null_category_name
FROM categories;

SELECT
    COUNT(*) - COUNT(CountryID)   AS null_country_id,
    COUNT(*) - COUNT(CountryName) AS null_country_name
FROM countries;

SELECT
    COUNT(*) - COUNT(EmployeeID) AS null_employee_id,
    COUNT(*) - COUNT(FirstName)  AS null_first_name,
    COUNT(*) - COUNT(LastName)   AS null_last_name
FROM employees;
-- Result: see 2b (SalesDate is the only column in scope with missing values).
-- Decision: A zero count is not conclusive for text columns (varchar):
--   blanks may have been imported as '' or the text 'NULL' instead of real NULLs,
--   which COUNT() cannot detect. Check text columns in step 2b.


-- 2b. Fake blanks in text columns ('', spaces only, or 'NULL' text)
SELECT
    'sales'     AS table_name,
    'SalesDate' AS column_name,
    SUM(CASE WHEN TRIM(SalesDate) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_count
FROM sales
UNION ALL
SELECT 'sales', 'TransactionNumber',
    SUM(CASE WHEN TRIM(TransactionNumber) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM sales
UNION ALL
SELECT 'products', 'ProductName',
    SUM(CASE WHEN TRIM(ProductName) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM products
UNION ALL
SELECT 'products', 'Class',
    SUM(CASE WHEN TRIM(Class) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM products
UNION ALL
SELECT 'categories', 'CategoryName',
    SUM(CASE WHEN TRIM(CategoryName) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM categories
UNION ALL
SELECT 'cities', 'CityName',
    SUM(CASE WHEN TRIM(CityName) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM cities
UNION ALL
SELECT 'countries', 'CountryName',
    SUM(CASE WHEN TRIM(CountryName) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM countries
UNION ALL
SELECT 'employees', 'FirstName',
    SUM(CASE WHEN TRIM(FirstName) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM employees
UNION ALL
SELECT 'employees', 'LastName',
    SUM(CASE WHEN TRIM(LastName) IN ('', 'NULL') THEN 1 ELSE 0 END)
FROM employees;
-- Result (2a + 2b): sales.SalesDate has 67,526 missing values (real NULL, blank or
--   'NULL' text), about 1.0% of 6,758,125 rows. All other columns in scope: 0.
-- Decision: Keep these rows and flag them instead of deleting.
--   In the clean view (step 8): convert SalesDate to a real date (blanks become NULL)
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
   3b. Duplicate IDs in lookup tables (+ duplicate product names)
   total_rows = distinct_ids  -> no duplicate IDs
   ------------------------------------------------------------ */
SELECT 'products' AS table_name,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT ProductID) AS distinct_ids,
       COUNT(DISTINCT ProductName) AS distinct_names
FROM products
UNION ALL
SELECT 'categories', COUNT(*), COUNT(DISTINCT CategoryID), NULL FROM categories  -- NULL keeps the same number of columns
UNION ALL
SELECT 'customers',  COUNT(*), COUNT(DISTINCT CustomerID), NULL FROM customers
UNION ALL
SELECT 'cities',     COUNT(*), COUNT(DISTINCT CityID),     NULL FROM cities
UNION ALL
SELECT 'countries',  COUNT(*), COUNT(DISTINCT CountryID),  NULL FROM countries
UNION ALL
SELECT 'employees',  COUNT(*), COUNT(DISTINCT EmployeeID), NULL FROM employees;
-- Result: All 6 lookup tables have total_rows = distinct_ids (no duplicate IDs).
--   products: distinct_names = distinct_ids (no duplicate product names).
-- Decision: Lookup tables are safe to JOIN with sales; no row multiplication.


/* ------------------------------------------------------------
   4. Value ranges
   4a. sales: Quantity, Discount, TotalPrice, SalesDate (MIN / MAX)
   4b. products: Price (MIN / MAX, any 0 or negative?)
   ------------------------------------------------------------ */
-- 4a. Quantity, Discount, TotalPrice
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

-- 4a. SalesDate
SELECT
      MIN(SalesDate) AS min_salesdate
    , MAX(SalesDate) AS max_salesdate
FROM sales
WHERE TRIM(SalesDate) NOT IN ('', 'NULL');
-- Result: SalesDate ranges from 2018-01-01 to 2018-05-09 (excluding blank dates).
-- Decision: Data covers Jan-Apr 2018 in full, May 2018 only partially (9 days).
--   In time-based analysis, compare months by revenue per day, not monthly totals.

-- 4b. Price
SELECT
      MIN(Price) AS min_price
    , MAX(Price) AS max_price
FROM products;
-- Result: Price ranges from 0.0449 to 99.8755. No zero or negative prices.
-- Decision: Price is valid for revenue calculation.
--   Round revenue to 2 decimals in the clean view.


/* ------------------------------------------------------------
   5. Foreign keys: IDs with no match in lookup tables
   Method: LEFT JOIN + IS NULL (anti-join)
   ------------------------------------------------------------ */
SELECT 'sales.ProductID -> products' AS check_name, COUNT(*) AS orphan_rows
FROM sales s
LEFT JOIN products p ON s.ProductID = p.ProductID
WHERE p.ProductID IS NULL
UNION ALL
SELECT 'sales.CustomerID -> customers', COUNT(*)
FROM sales s
LEFT JOIN customers c ON s.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL
UNION ALL
SELECT 'sales.SalesPersonID -> employees', COUNT(*)
FROM sales s
LEFT JOIN employees e ON s.SalesPersonID = e.EmployeeID
WHERE e.EmployeeID IS NULL
UNION ALL
SELECT 'customers.CityID -> cities', COUNT(*)
FROM customers c
LEFT JOIN cities ci ON c.CityID = ci.CityID
WHERE ci.CityID IS NULL
UNION ALL
SELECT 'cities.CountryID -> countries', COUNT(*)
FROM cities ci
LEFT JOIN countries co ON ci.CountryID = co.CountryID
WHERE co.CountryID IS NULL;
-- Result: All 5 checks return 0 orphan rows.
-- Decision: Every ID has a match in its lookup table.
--   Combined with step 3b (no duplicate IDs), JOINs will not drop
--   or duplicate rows. INNER JOIN is safe in the clean view.


/* ------------------------------------------------------------
   6. Lookup table checks
   6a. categories: 11 rows vs 8 in the glossary, what are the extra 3?
   ------------------------------------------------------------ */
SELECT
      c.CategoryID
    , c.CategoryName
    , COUNT(p.ProductID) AS product_count
FROM categories c
LEFT JOIN products p ON c.CategoryID = p.CategoryID
GROUP BY c.CategoryID, c.CategoryName
ORDER BY c.CategoryID;
-- Result: 11 categories, each with 28 to 57 products (452 in total):
--   Confections 57, Meat 50, Poultry 47, Cereals 45, Produce 43, Beverages 38,
--   Snails 37, Shell fish 36, Seafood 36, Dairy 35, Grain 28. No empty category.
-- Decision: Use category names from categories.csv (11 categories).
--   The Data Dictionary glossary lists 8 categories that match the
--   Northwind sample database, not this dataset, so it is not used.


/* ------------------------------------------------------------
   7. Primary keys and foreign keys
   Safe to add: step 3b found no duplicate IDs,
   step 5 found no orphan rows.
   Key map:
     sales      PK SalesID     FK ProductID, CustomerID, SalesPersonID
     products   PK ProductID   FK CategoryID
     customers  PK CustomerID  FK CityID
     employees  PK EmployeeID  FK CityID
     cities     PK CityID      FK CountryID
     countries  PK CountryID
     categories PK CategoryID
   ------------------------------------------------------------ */

-- 7a. Primary keys
ALTER TABLE categories ADD PRIMARY KEY (CategoryID);
ALTER TABLE countries  ADD PRIMARY KEY (CountryID);
ALTER TABLE cities     ADD PRIMARY KEY (CityID);
ALTER TABLE customers  ADD PRIMARY KEY (CustomerID);
ALTER TABLE employees  ADD PRIMARY KEY (EmployeeID);
ALTER TABLE products   ADD PRIMARY KEY (ProductID);
ALTER TABLE sales      ADD PRIMARY KEY (SalesID);

-- 7b. Foreign keys
ALTER TABLE sales     ADD CONSTRAINT fk_sales_product     FOREIGN KEY (ProductID)     REFERENCES products (ProductID);
ALTER TABLE sales     ADD CONSTRAINT fk_sales_customer    FOREIGN KEY (CustomerID)    REFERENCES customers (CustomerID);
ALTER TABLE sales     ADD CONSTRAINT fk_sales_employee    FOREIGN KEY (SalesPersonID) REFERENCES employees (EmployeeID);
ALTER TABLE products  ADD CONSTRAINT fk_products_category FOREIGN KEY (CategoryID)    REFERENCES categories (CategoryID);
ALTER TABLE customers ADD CONSTRAINT fk_customers_city    FOREIGN KEY (CityID)        REFERENCES cities (CityID);
ALTER TABLE cities    ADD CONSTRAINT fk_cities_country    FOREIGN KEY (CountryID)     REFERENCES countries (CountryID);
ALTER TABLE employees ADD CONSTRAINT fk_employee_city     FOREIGN KEY (CityID)        REFERENCES cities (CityID);


/* ------------------------------------------------------------
   8. Clean view for analysis
   Keep raw tables unchanged; build the view from the decisions above:
   - SalesDate converted to DATETIME, blanks -> NULL + flag (Decision 2b)
   - revenue = Quantity * Price * (1 - Discount) (Decision 4a)
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
SELECT SUM(has_sales_date = 0) FROM v_sales_clean;   -- 67,526 (matches step 2)


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
