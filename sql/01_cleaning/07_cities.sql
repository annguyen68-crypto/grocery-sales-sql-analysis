/* ============================================================
   01_cleaning/07_cities.sql  (MySQL)
   Checks on the cities table: missing values, duplicate IDs, number of countries.
   Each check follows: query -> Result -> Decision
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1. Missing values and duplicate IDs
   ------------------------------------------------------------ */
SELECT
      COUNT(*)                    AS total_rows
    , COUNT(DISTINCT CityID)      AS distinct_ids
    , COUNT(*) - COUNT(CityName)  AS null_city_name
    , COUNT(*) - COUNT(CountryID) AS null_country_id
    , SUM(CASE WHEN TRIM(CityName) IN ('', 'NULL') THEN 1 ELSE 0 END) AS blank_city_name
FROM cities;
-- Result: 96 rows, 96 distinct IDs, no missing values.
-- Decision: CityID can be the primary key.


/* ------------------------------------------------------------
   2. How many countries do the cities belong to?
   ------------------------------------------------------------ */
SELECT COUNT(DISTINCT CountryID) AS countries FROM cities;
-- Result: 1. All 96 cities belong to the same country.
-- Decision: Country level is skipped in Scenario 5; geography is analysed at city level.
