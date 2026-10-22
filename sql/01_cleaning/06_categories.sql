/* ============================================================
   01_cleaning/06_categories.sql  (MySQL)
   Checks on the categories table: missing values, duplicate IDs, products per category.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Missing values and duplicate IDs
   ------------------------------------------------------------ */
SELECT
      COUNT(*)                       AS total_rows
    , COUNT(DISTINCT CategoryID)     AS distinct_ids
    , COUNT(*) - COUNT(CategoryName) AS null_category_name
    , SUM(CASE WHEN TRIM(CategoryName) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_category_name
FROM categories;
-- Result: 11 rows, 11 distinct IDs, no missing names.
-- Decision: CategoryID can be the primary key.


/* ------------------------------------------------------------
   2. Products per category: 11 rows vs 8 in the Data Dictionary glossary
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
-- Decision: Use category names from the categories table (11 categories).
--   The Data Dictionary glossary lists 8 categories that match the
--   Northwind sample database, not this dataset, so it is not used.
