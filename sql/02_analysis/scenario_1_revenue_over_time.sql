/* ============================================================
   02_analysis/scenario_1_revenue_over_time.sql  (MySQL)
   Scenario 1: Revenue performance over time
   Source: view v_sales_clean (built in 01_cleaning/10_v_sales_clean.sql)
   Rules:
   - Totals use all rows; time-based queries use WHERE has_sales_date = 1.
   - May 2018 has only 9 days of data, so months are compared per day.
   ============================================================ */

USE fmcg_project;

/* ------------------------------------------------------------
   1.1 Total net revenue (after discount)
   ------------------------------------------------------------ */
SELECT
      ROUND(SUM(gross_sales), 2) AS gross_revenue
    , ROUND(SUM(net_sales), 2)   AS net_revenue
    , ROUND(1 - SUM(net_sales) / SUM(gross_sales), 4) AS effective_discount_rate
FROM v_sales_clean;
-- Result: Gross revenue 4,466,259,465.28; net revenue 4,332,445,908.80;
--   effective discount rate 3.00%.
-- Insight: Discounts reduce gross revenue by only ~3%, so discounting is
--   not a meaningful driver of revenue. Any change in revenue must come
--   from the other branch of the tree (customers, orders, units, price mix).


/* ------------------------------------------------------------
   1.2 Revenue by month and category share
   ------------------------------------------------------------ */

-- 1.2a Net revenue by month
SELECT
      YEAR(SalesDate)  AS sale_year
    , MONTH(SalesDate) AS sale_month
    , ROUND(SUM(net_sales), 2)        AS net_revenue
    , COUNT(DISTINCT DATE(SalesDate)) AS days_in_data
    , ROUND(SUM(net_sales) / COUNT(DISTINCT DATE(SalesDate)), 2) AS avg_daily_revenue
FROM v_sales_clean
WHERE has_sales_date = 1
GROUP BY YEAR(SalesDate), MONTH(SalesDate)
ORDER BY sale_year, sale_month;
-- Result: Net revenue by month (rows with a valid SalesDate):
--   Jan 1,030.7M | Feb 929.2M | Mar 1,032.2M | Apr 997.3M | May 299.8M (9 days)
--   Revenue per day is ~33.2-33.3M in every month.
-- Insight: Monthly totals look like Feb and May dropped, but the differences
--   come only from the number of days (Feb = 28 days, May = 9 days of data).
--   Daily revenue is almost flat, so there is no real growth or decline
--   over the period. Compare months by revenue per day, not by monthly totals.


-- 1.2b Category share of monthly revenue
WITH monthly_total AS (                         -- Step 1: total revenue per month (denominator)
    SELECT
          YEAR(SalesDate)  AS sale_year
        , MONTH(SalesDate) AS sale_month
        , SUM(net_sales)   AS month_revenue
    FROM v_sales_clean
    WHERE has_sales_date = 1
    GROUP BY YEAR(SalesDate), MONTH(SalesDate)
),
month_category AS (                             -- Step 2: revenue per category per month (numerator)
    SELECT
          YEAR(v.SalesDate)  AS sale_year
        , MONTH(v.SalesDate) AS sale_month
        , c.CategoryName
        , SUM(v.net_sales)   AS category_revenue
    FROM v_sales_clean v
    JOIN products p   ON v.ProductID  = p.ProductID
    JOIN categories c ON p.CategoryID = c.CategoryID
    WHERE v.has_sales_date = 1
    GROUP BY YEAR(v.SalesDate), MONTH(v.SalesDate), c.CategoryName
)
SELECT                                          -- Step 3: join on year + month, then divide
      mc.sale_year
    , mc.sale_month
    , mc.CategoryName
    , ROUND(mc.category_revenue, 2)                          AS category_revenue
    , ROUND(mc.category_revenue * 100 / mt.month_revenue, 2) AS share_pct
FROM month_category mc
JOIN monthly_total mt
    ON  mc.sale_year  = mt.sale_year
    AND mc.sale_month = mt.sale_month
ORDER BY mc.CategoryName, mc.sale_year, mc.sale_month;
-- Result: 55 rows (5 months x 11 categories); shares in each month sum to 100%.
-- Insight: See 1.2c for the per-category summary.


-- 1.2c Share stability by category: does each category's share change from month to month?
WITH monthly_total AS (
    SELECT                                -- Step 1: total net revenue of each month (denominator)
          YEAR(SalesDate)  AS sale_year
        , MONTH(SalesDate) AS sale_month
        , SUM(net_sales)   AS month_revenue
    FROM v_sales_clean
    WHERE has_sales_date = 1
    GROUP BY YEAR(SalesDate), MONTH(SalesDate)
),
month_category AS (
    SELECT                                -- Step 2: net revenue of each category in each month (numerator)
          YEAR(v.SalesDate)  AS sale_year
        , MONTH(v.SalesDate) AS sale_month
        , c.CategoryName
        , SUM(v.net_sales)   AS category_revenue
    FROM v_sales_clean v
    JOIN products p   ON v.ProductID  = p.ProductID
    JOIN categories c ON p.CategoryID = c.CategoryID
    WHERE v.has_sales_date = 1
    GROUP BY YEAR(v.SalesDate), MONTH(v.SalesDate), c.CategoryName
),
share AS (
    SELECT                                -- Step 3: share of each category in its own month
          mc.CategoryName
        , mc.sale_year
        , mc.sale_month
        , mc.category_revenue * 100 / mt.month_revenue AS share_pct
    FROM month_category mc
    JOIN monthly_total mt
        ON  mc.sale_year  = mt.sale_year
        AND mc.sale_month = mt.sale_month
)
SELECT                                    -- Step 4: summarise the 5 monthly shares of each category
      CategoryName
    , ROUND(AVG(share_pct), 2)                  AS avg_share
    , ROUND(MIN(share_pct), 2)                  AS min_share
    , ROUND(MAX(share_pct), 2)                  AS max_share
    , ROUND(MAX(share_pct) - MIN(share_pct), 2) AS share_range
FROM share
GROUP BY CategoryName
ORDER BY avg_share DESC;
-- Result: 11 rows (one per category).
--   Average share: Confections 12.9% | Meat 11.4% | Poultry 10.2% | Cereals 9.9%
--   | Snails 8.6% | Produce 8.5% | Beverages 8.5% | Dairy 8.2% | Seafood 7.6%
--   | Grain 7.5% | Shell fish 6.9%.
--   Each category's share moves by at most 0.16 percentage points between its
--   highest and lowest month.
-- Insight: The category mix is very stable. Each category keeps almost the
--   same share every month. Revenue is spread
--   fairly evenly: the largest category (Confections) is only about 1.9x the
--   smallest (Shell fish), and the top 3 make up ~34% of revenue, so the
--   business does not depend heavily on any single category.
--   Such flat shares are unusual for real retail data (no seasonality),
--   which is consistent with the dataset being simulated.


/* ------------------------------------------------------------
   1.3 KPI tree drivers by category x month
   Gross sales = customers x frequency x UPT x AUR
   ------------------------------------------------------------ */
SELECT
      c.CategoryName
    , MONTH(v.SalesDate)                                            AS sale_month
    , ROUND(COUNT(DISTINCT v.CustomerID)
            / COUNT(DISTINCT DATE(v.SalesDate)))                    AS customers_per_day
    , ROUND(COUNT(*) / COUNT(DISTINCT DATE(v.SalesDate)))           AS orders_per_day
    , ROUND(COUNT(*) / COUNT(DISTINCT v.CustomerID), 3)             AS frequency
    , ROUND(SUM(v.Quantity) / COUNT(*), 2)                          AS upt
    , ROUND(SUM(v.gross_sales) / SUM(v.Quantity), 2)                AS aur
FROM v_sales_clean v
JOIN products p   ON v.ProductID  = p.ProductID
JOIN categories c ON p.CategoryID = c.CategoryID
WHERE v.has_sales_date = 1
GROUP BY c.CategoryName, MONTH(v.SalesDate)
ORDER BY c.CategoryName, sale_month;
-- Result: 55 rows. Within each category, orders_per_day, UPT (~13.0) and
--   AUR (e.g. Beverages 51.06-51.15) barely change across months.
--   customers_per_day rises and frequency falls in Feb (28 days) and
--   May (9 days), but orders_per_day (their product) stays flat.
-- Insight: The flat revenue is genuine: no driver is hiding an offsetting
--   change. The Feb/May movement in customers_per_day and frequency is a
--   measurement effect of counting distinct customers over months of
--   different length, not a real change in customer behaviour.
--   Category differences come from the number of products in each category
--   (every product sells about the same volume, see 2.2 in scenario_2_products.sql) and from AUR
--   (Shell fish ~44 vs Grain ~61.5), not from basket size (UPT is ~13 everywhere).

/* Scenario 1 summary
   - Net revenue 4.33B (Jan 1 - May 9, 2018); discounts reduce gross revenue by only ~3%.
   - Revenue per day is flat at ~33.2-33.3M in every month.
   - Category mix is stable (Confections 12.9%, Meat 11.4%, Poultry 10.2%).
   - No growth or decline over the period. The KPI tree drivers (orders, units per order, AUR)
     are stable within each category, so the flat revenue is not hiding offsetting changes.
*/
