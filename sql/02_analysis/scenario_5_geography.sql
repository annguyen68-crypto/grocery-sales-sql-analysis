/* ============================================================
   02_analysis/scenario_5_geography.sql  (MySQL)
   Scenario 5: Revenue by geography
   Source: view v_sales_clean (built in 01_cleaning/10_v_sales_clean.sql)
   Rules:
   - Totals use all rows; time-based queries use WHERE has_sales_date = 1.
   - May 2018 has only 9 days of data, so months are compared per day.
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   5.1 + 5.2 + 5.3 Revenue, units and KPI drivers by city
   Net sales = customers x frequency x UPT x AUR x (1 - discount)
   Active rate is 100% in every city (all customers buy every month, see 3.2 in scenario_3_customers.sql),
   so buying customers = registered customers.
   ------------------------------------------------------------ */

-- All 96 cities belong to one country (see 01_cleaning/07_cities.sql),
-- so country level is skipped and geography is analysed at city level only.

SELECT ci.CityName
     , COUNT(DISTINCT v.CustomerID)                      AS customers
     , ROUND(COUNT(*) / COUNT(DISTINCT v.CustomerID), 1) AS frequency
     , ROUND(SUM(v.Quantity) / COUNT(*), 2)              AS upt
     , ROUND(SUM(v.gross_sales) / SUM(v.Quantity), 2)    AS aur
     , SUM(v.Quantity)                                   AS units_sold
     , ROUND(SUM(v.net_sales), 2)                        AS net_revenue
     , RANK() OVER (ORDER BY SUM(v.net_sales) DESC)      AS revenue_rank
FROM v_sales_clean v
JOIN customers cu ON v.CustomerID = cu.CustomerID
JOIN cities ci    ON cu.CityID    = ci.CityID
GROUP BY ci.CityID, ci.CityName
ORDER BY revenue_rank;
-- Result:
--   Net revenue by city ranges from 41.86M (Omaha, rank 96) to 48.84M (Tucson, rank 1).
--   Top 3: Tucson, Jackson, Sacramento. Bottom 3: Omaha, Long Beach, Atlanta.
--   Customers per city range from 964 to 1,104; UPT from 12.36 (Long Beach) to 13.47 (Jackson).
--   Frequency (67.8 to 69.1) and AUR (50.43 to 51.12) are nearly the same in every city.
--   Units sold (5.2) range from 855,896 (Omaha) to 993,698 (Tucson) and closely track
--   revenue because AUR is nearly the same everywhere (the order differs slightly,
--   e.g. Sacramento sells more units than Jackson).
-- Insight:
--   Cities differ mainly in the number of customers, and secondly in basket size.
--   Jackson ranks 2nd with fewer customers than several cities because it has the highest UPT;
--   Long Beach ranks 95th despite a mid-sized customer base because it has the lowest UPT.


/* ------------------------------------------------------------
   5.1b KPI drivers by city revenue quartile (Q1 = lowest 25% of cities, Q4 = highest)
   ------------------------------------------------------------ */
WITH city AS (
    SELECT cu.CityID
         , COUNT(DISTINCT v.CustomerID) AS customers
         , COUNT(*)                     AS orders
         , SUM(v.Quantity)              AS units
         , SUM(v.gross_sales)           AS gross
         , SUM(v.net_sales)             AS revenue
         , NTILE(4) OVER (ORDER BY SUM(v.net_sales)) AS revenue_q
    FROM v_sales_clean v
    JOIN customers cu ON v.CustomerID = cu.CustomerID
    GROUP BY cu.CityID
)
SELECT revenue_q
     , COUNT(*)                               AS cities
     , ROUND(AVG(customers))                  AS avg_customers
     , ROUND(SUM(orders) / SUM(customers), 1) AS frequency
     , ROUND(SUM(units) / SUM(orders), 2)     AS upt
     , ROUND(SUM(gross) / SUM(units), 2)      AS aur
     , ROUND(AVG(revenue), 2)                 AS avg_revenue
FROM city
GROUP BY revenue_q
ORDER BY revenue_q;
-- Result:
--   From the lowest to the highest revenue quartile (24 cities each):
--   average customers rise from 1,000 to 1,060, UPT from 12.87 to 13.10,
--   while frequency (68.4 to 68.5) and AUR (50.81 to 50.84) stay flat.
--   Average revenue per city rises from 43.38M to 46.87M.
-- Insight:
--   The KPI tree hypothesis is supported: revenue differences between cities come mainly
--   from customer base size, with UPT as a smaller second driver. Since every customer is
--   already active (see 3.2 in scenario_3_customers.sql), growth in weaker cities must come from acquiring new customers
--   and increasing basket size, not from re-activating existing ones.

/* Scenario 5 summary
   - All 96 cities are in one country, so the analysis is at city level.
     Revenue per city ranges from 41.86M to 48.84M.
   - The main driver is the number of customers; UPT is a smaller second driver.
     Frequency, AUR and active rate (100%) are the same everywhere.
   - KPI tree check: the hypothesis that differences come from the customer base is supported.
   - Key markets: Tucson, Jackson, Sacramento. For weaker cities (e.g. Omaha, Long Beach),
     focus on customer acquisition and basket-building offers.
*/
