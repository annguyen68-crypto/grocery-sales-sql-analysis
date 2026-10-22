/* ============================================================
   01_cleaning/09_keys.sql  (MySQL)
   Relationships between tables: orphan checks, then primary and foreign keys.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Orphan IDs: IDs with no match in their lookup table
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
--   Combined with no duplicate IDs (files 02-08), JOINs will not drop
--   or duplicate rows. INNER JOIN is safe in the clean view.


/* ------------------------------------------------------------
   2. Primary keys and foreign keys
   Safe to add: no duplicate IDs (table files 02-08), no orphan IDs (step 1).
   Key map:
     sales      PK SalesID     FK ProductID, CustomerID, SalesPersonID
     products   PK ProductID   FK CategoryID
     customers  PK CustomerID  FK CityID
     employees  PK EmployeeID  FK CityID
     cities     PK CityID      FK CountryID
     countries  PK CountryID
     categories PK CategoryID
   ------------------------------------------------------------ */
-- 2a. Primary keys
ALTER TABLE categories ADD PRIMARY KEY (CategoryID);
ALTER TABLE countries  ADD PRIMARY KEY (CountryID);
ALTER TABLE cities     ADD PRIMARY KEY (CityID);
ALTER TABLE customers  ADD PRIMARY KEY (CustomerID);
ALTER TABLE employees  ADD PRIMARY KEY (EmployeeID);
ALTER TABLE products   ADD PRIMARY KEY (ProductID);
ALTER TABLE sales      ADD PRIMARY KEY (SalesID);

-- 2b. Foreign keys
ALTER TABLE sales     ADD CONSTRAINT fk_sales_product     FOREIGN KEY (ProductID)     REFERENCES products (ProductID);
ALTER TABLE sales     ADD CONSTRAINT fk_sales_customer    FOREIGN KEY (CustomerID)    REFERENCES customers (CustomerID);
ALTER TABLE sales     ADD CONSTRAINT fk_sales_employee    FOREIGN KEY (SalesPersonID) REFERENCES employees (EmployeeID);
ALTER TABLE products  ADD CONSTRAINT fk_products_category FOREIGN KEY (CategoryID)    REFERENCES categories (CategoryID);
ALTER TABLE customers ADD CONSTRAINT fk_customers_city    FOREIGN KEY (CityID)        REFERENCES cities (CityID);
ALTER TABLE cities    ADD CONSTRAINT fk_cities_country    FOREIGN KEY (CountryID)     REFERENCES countries (CountryID);
ALTER TABLE employees ADD CONSTRAINT fk_employee_city     FOREIGN KEY (CityID)        REFERENCES cities (CityID);
