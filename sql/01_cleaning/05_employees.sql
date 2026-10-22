/* ============================================================
   01_cleaning/05_employees.sql  (MySQL)
   Checks on the employees table: missing values and duplicate IDs.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Missing values (real NULLs and fake blanks in text columns)
   ------------------------------------------------------------ */
SELECT
    COUNT(*) - COUNT(EmployeeID) AS null_employee_id,
    COUNT(*) - COUNT(FirstName)  AS null_first_name,
    COUNT(*) - COUNT(LastName)   AS null_last_name,
    SUM(CASE WHEN TRIM(FirstName) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_first_name,
    SUM(CASE WHEN TRIM(LastName)  IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_last_name
FROM employees;
-- Result: 0 in every column.
-- Decision: No action needed.


/* ------------------------------------------------------------
   2. Duplicate IDs
   ------------------------------------------------------------ */
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT EmployeeID) AS distinct_ids
FROM employees;
-- Result: total_rows = distinct_ids (23): no duplicate IDs.
-- Decision: Safe to JOIN with sales; EmployeeID can be the primary key.
