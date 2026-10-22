/* ============================================================
   01_cleaning/03_products.sql  (MySQL)
   Checks on the products table: missing values, duplicate IDs and names, price range.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Missing values (real NULLs and fake blanks in text columns)
   ------------------------------------------------------------ */
SELECT
    COUNT(*) - COUNT(ProductID)   AS null_product_id,
    COUNT(*) - COUNT(ProductName) AS null_product_name,
    COUNT(*) - COUNT(Price)       AS null_price,
    COUNT(*) - COUNT(CategoryID)  AS null_category_id,
    COUNT(*) - COUNT(Class)       AS null_class,
    SUM(CASE WHEN TRIM(ProductName) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_product_name,
    SUM(CASE WHEN TRIM(Class)       IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_class
FROM products;
-- Result: 0 in every column.
-- Decision: No action needed.


/* ------------------------------------------------------------
   2. Duplicate IDs and product names
   ------------------------------------------------------------ */
SELECT
      COUNT(*)                    AS total_rows
    , COUNT(DISTINCT ProductID)   AS distinct_ids
    , COUNT(DISTINCT ProductName) AS distinct_names
FROM products;
-- Result: total_rows = distinct_ids = distinct_names (452): no duplicate IDs or names.
-- Decision: Safe to JOIN with sales; ProductID can be the primary key.


/* ------------------------------------------------------------
   3. Price range (any 0 or negative?)
   ------------------------------------------------------------ */
SELECT
      MIN(Price) AS min_price
    , MAX(Price) AS max_price
FROM products;
-- Result: Price ranges from 0.0449 to 99.8755. No zero or negative prices.
-- Decision: Price is valid for revenue calculation; round revenue to 2 decimals in the view.
