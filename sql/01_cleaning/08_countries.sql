/* ============================================================
   01_cleaning/08_countries.sql  (MySQL)
   Checks on the countries table: missing values and duplicate IDs.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

SELECT
      COUNT(*)                       AS total_rows
    , COUNT(DISTINCT CountryID)      AS distinct_ids
    , COUNT(*) - COUNT(CountryName)  AS null_country_name
    , SUM(CASE WHEN TRIM(CountryName) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_country_name
FROM countries;
-- Result: 206 rows, 206 distinct IDs, no missing names.
-- Decision: CountryID can be the primary key. Only 1 of the 206 countries is used (see 07_cities.sql).
