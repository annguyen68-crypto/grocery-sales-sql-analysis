/* ============================================================
   02_analysis/scenario_4_salespeople.sql  (MySQL)
   Scenario 4: Salesperson performance
   Source: view v_sales_clean (built in 01_cleaning/10_v_sales_clean.sql)
   Rules:
   - Totals use all rows; time-based queries use WHERE has_sales_date = 1.
   - May 2018 has only 9 days of data, so months are compared per day.
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   4.1 + 4.2 Sales, orders and ranking by salesperson
   Net sales = days sold x orders per day x UPT x AUR x (1 - discount)
   ------------------------------------------------------------ */
SELECT e.EmployeeID
     , CONCAT(e.FirstName, ' ', e.LastName)                             AS employee
     , COUNT(DISTINCT DATE(v.SalesDate))                                AS days_sold
     , ROUND(SUM(v.has_sales_date) / COUNT(DISTINCT DATE(v.SalesDate))) AS orders_per_day
     , ROUND(SUM(v.Quantity) / COUNT(*), 2)                             AS upt
     , ROUND(SUM(v.gross_sales) / SUM(v.Quantity), 2)                   AS aur
     , COUNT(*)                                                         AS orders
     , ROUND(SUM(v.net_sales), 2)                                       AS net_revenue
     , RANK() OVER (ORDER BY SUM(v.net_sales) DESC)                     AS revenue_rank
FROM v_sales_clean v
JOIN employees e ON v.SalesPersonID = e.EmployeeID
GROUP BY e.EmployeeID, e.FirstName, e.LastName
ORDER BY revenue_rank;
-- Result:
--   All 23 salespeople sold on the same 129 days.
--   Net revenue ranges from 186.3M (rank 23, Seth Franco) to 190.0M (rank 1, Devon Brewer),
--   a gap of about 2%.
--   Orders per day (2,244 to 2,264), UPT (12.97 to 13.03) and AUR (50.55 to 51.13)
--   are nearly identical across salespeople.
-- Insight:
--   Sales performance is almost equal across the team. The small gap is spread across
--   several drivers (orders, UPT, AUR), each under 1%, and no single driver explains
--   the ranking (e.g. rank 2 has fewer orders than rank 13).
--   The hypothesis that differences come mainly from orders per day is not supported.
--   The ranking likely reflects random variation, so it should not be used on its own
--   for rewards or penalties. In real data, HR should set KPIs on orders per day and UPT,
--   which are fair across different working days and can be improved through training.


/* ------------------------------------------------------------
   4.3 Stability of daily revenue by salesperson across months
   range_pct = (best month - worst month) / average month
   ------------------------------------------------------------ */
WITH monthly AS (
    SELECT SalesPersonID
         , MONTH(SalesDate)                                 AS sale_month
         , SUM(net_sales) / COUNT(DISTINCT DATE(SalesDate)) AS revenue_per_day
    FROM v_sales_clean
    WHERE has_sales_date = 1
    GROUP BY SalesPersonID, MONTH(SalesDate)
)
SELECT CONCAT(e.FirstName, ' ', e.LastName) AS employee
     , ROUND(MIN(m.revenue_per_day))        AS worst_month_daily
     , ROUND(MAX(m.revenue_per_day))        AS best_month_daily
     , ROUND((MAX(m.revenue_per_day) - MIN(m.revenue_per_day)) * 100
             / AVG(m.revenue_per_day), 2)   AS range_pct
FROM monthly m
JOIN employees e ON m.SalesPersonID = e.EmployeeID
GROUP BY e.EmployeeID, e.FirstName, e.LastName
ORDER BY range_pct DESC;
-- Result:
--   Month-to-month range of daily revenue is small for everyone:
--   from 0.67% (Chadwick Cook) to 2.5% (Devon Brewer).
--   Daily revenue per salesperson stays between ~1.41M and ~1.47M in every month.
--   The two most volatile salespeople are Devon Brewer (2.5%) and Seth Franco (2.22%),
--   who are rank 1 and rank 23 by revenue in 4.1.
-- Insight:
--   Performance is stable over time for the whole team.
--   The top and bottom performers are also the most volatile, which suggests their
--   ranking comes from random variation rather than consistently better or worse selling.
--   This supports 4.1: the ranking should not be used on its own for rewards or penalties.

/* Scenario 4 summary
   - All 23 salespeople worked the same 129 days; revenue differs by only ~2%
     (186.3M to 190.0M).
   - Orders per day, UPT and AUR are nearly identical; no single driver explains the ranking.
   - Monthly performance is stable for everyone (range under 2.5%), and the rank 1 and
     rank 23 salespeople are the most volatile, so the ranking reflects random variation.
   - KPI tree check: the hypothesis that differences come from orders per day is not supported.
     In real data, orders per day and UPT would be fair, trainable KPIs.
*/
