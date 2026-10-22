/* ============================================================
   02_analysis.sql  (MySQL)
   Analysis of the 5 scenarios, using v_sales_clean (see 01_cleaning.sql).
   Rules:
   - Totals (products, customers, salespeople, cities) use all rows.
   - Time-based queries use WHERE has_sales_date = 1.
   - May 2018 has only 9 days of data, so months are compared per day.
   ============================================================ */

USE fmcg_project;


/* ============================================================
   Scenario 1: Revenue performance over time
   ============================================================ */

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
--   (every product sells about the same volume, see 2.2) and from AUR
--   (Shell fish ~44 vs Grain ~61.5), not from basket size (UPT is ~13 everywhere).

/* Scenario 1 summary
   - Net revenue 4.33B (Jan 1 - May 9, 2018); discounts reduce gross revenue by only ~3%.
   - Revenue per day is flat at ~33.2-33.3M in every month.
   - Category mix is stable (Confections 12.9%, Meat 11.4%, Poultry 10.2%).
   - No growth or decline over the period. The KPI tree drivers (orders, units per order, AUR)
     are stable within each category, so the flat revenue is not hiding offsetting changes.
*/


/* ============================================================
   Scenario 2: Product ranking and classification
   ============================================================ */

/* ------------------------------------------------------------
   2.1 Top 5 and bottom 5 products by net revenue
   (with price and volume to explain the ranking)
   ------------------------------------------------------------ */
WITH product_revenue AS (
    SELECT
          v.ProductID
        , p.ProductName
        , p.Price
        , SUM(v.Quantity)  AS units_sold
        , COUNT(*)         AS orders
        , SUM(v.net_sales) AS revenue
    FROM v_sales_clean v
    JOIN products p ON v.ProductID = p.ProductID
    GROUP BY v.ProductID, p.ProductName, p.Price
)
(
    SELECT                                -- Top 5: highest revenue first
          'Top 5'           AS product_group
        , ProductName
        , ROUND(Price, 2)   AS price
        , units_sold
        , orders
        , ROUND(revenue, 2) AS product_revenue
    FROM product_revenue
    ORDER BY revenue DESC
    LIMIT 5
)
UNION ALL
(
    SELECT                                -- Bottom 5: lowest revenue first
          'Bottom 5'
        , ProductName
        , ROUND(Price, 2)
        , units_sold
        , orders
        , ROUND(revenue, 2)
    FROM product_revenue
    ORDER BY revenue ASC
    LIMIT 5
);
-- Result: Top 5 (98.25-99.88 price): 18.55M-18.87M revenue each.
--   Bottom 5 (0.04-1.19 price): 8.5K-223K revenue each.
--   All 10 products have almost the same volume:
--   ~193K-197K units and ~14.9K-15.1K orders each.
-- Insight: Revenue ranking is driven by price, not by demand.
--   Top and bottom products sell the same quantity in the same number of
--   orders; the 1,000x+ revenue gap comes only from the price gap.
--   So the bottom 5 are not slow-moving or overstocked items: they sell as
--   often as the best sellers. Removing them based on revenue alone would
--   be a mistake. A better next step is to review their pricing
--   (e.g. a price of 0.04 looks unrealistically low and may be a data issue).
--   Volume being almost identical across products is another sign the
--   dataset is simulated.


/* ------------------------------------------------------------
   2.2 Quantity vs revenue across all 452 products
   Note: no cost data, so margin cannot be calculated.
   ------------------------------------------------------------ */
WITH product_stats AS (
    SELECT
          ProductID
        , SUM(Quantity)  AS units_sold
        , SUM(net_sales) AS revenue
    FROM v_sales_clean
    GROUP BY ProductID
)
SELECT
      COUNT(*)                                    AS products
    , MIN(units_sold)                             AS min_units
    , MAX(units_sold)                             AS max_units
    , ROUND(MAX(units_sold) / MIN(units_sold), 2) AS units_max_to_min
    , ROUND(MIN(revenue), 2)                      AS min_revenue
    , ROUND(MAX(revenue), 2)                      AS max_revenue
    , ROUND(MAX(revenue) / MIN(revenue), 0)       AS revenue_max_to_min
FROM product_stats;
-- Result: 452 products. Units sold per product range from 189,906 to 199,724
--   (max/min = 1.05x). Net revenue per product ranges from 8,524.69 to
--   18,868,840.18 (max/min = 2,213x).
-- Insight: Demand is almost identical across all products (within ~5%), while
--   revenue differs by more than 2,000x. Quantity sold has essentially no
--   relationship with revenue; revenue per product is determined by price.
--   No product has unusually high demand: the low-price products (e.g. the
--   bottom 5 in 2.1, priced 0.04-1.19) sell the same volume as every other
--   product. Price band analysis was not needed: with volume this flat,
--   every price band would show the same average units.


/* ------------------------------------------------------------
   2.3 Impact of product Class on sales performance
   Net sales = SKUs sold x units per SKU x AUR x (1 - discount)
   ------------------------------------------------------------ */
WITH product_revenue AS (
    SELECT
          v.ProductID
        , p.Class
        , SUM(v.Quantity)    AS units_sold
        , SUM(v.gross_sales) AS gross
        , SUM(v.net_sales)   AS revenue
    FROM v_sales_clean v
    JOIN products p ON v.ProductID = p.ProductID
    GROUP BY v.ProductID, p.Class
)
SELECT
      Class                                                     -- (+) split by Class
    , COUNT(*)                                AS skus_sold      -- one row per product
    , ROUND(SUM(units_sold) / COUNT(*))       AS units_per_sku  -- leaf 2: total Quantity / SKUs
    , ROUND(SUM(gross) / SUM(units_sold), 2)  AS aur
    , ROUND(1 - SUM(revenue) / SUM(gross), 4) AS effective_discount_rate
    , ROUND(SUM(revenue), 2)                  AS net_revenue
    , ROUND(SUM(revenue) * 100 / (SELECT SUM(revenue) FROM product_revenue), 2) AS revenue_share_pct
FROM product_revenue
GROUP BY Class
ORDER BY net_revenue DESC;
-- Result:
--   All three classes sell every listed SKU (High 143, Low 153, Medium 156 = 452),
--   so the SKU sold rate is 100%.
--   Units per SKU (~194K) and effective discount rate (0.03) are almost identical.
--   AUR differs: High 54.22 > Low 50.46 > Medium 48.06.
--   Revenue share is close: High 33.77%, Low 33.61%, Medium 32.62%.
-- Insight:
--   Class has little impact on revenue. Differences in SKU count and AUR offset each other:
--   High has the fewest SKUs but the highest AUR; Medium has the most SKUs but the lowest AUR.
--   Class is not a price tier (Low has a higher AUR than Medium), so the label alone
--   should not drive pricing or assortment decisions.

/* Scenario 2 summary
   - All 452 products sold; units per product are nearly equal (1.05x range).
   - Revenue differences come from price, not volume (2,213x revenue range);
     the bottom 5 are low-price items, not slow movers.
   - Class has little impact: revenue is split ~1/3 each, with SKU count
     and AUR offsetting each other.
   - KPI tree check: SKU sold rate = 100%; the hypothesis that differences
     come from units per SKU is rejected. AUR is the driver.
*/


/* ============================================================
   Scenario 3: Customer behaviour and segmentation
   ============================================================ */

/* ------------------------------------------------------------
   3.1 Customer segments by frequency and spend
   Each metric split into quartiles (Q1 = lowest 25%, Q4 = highest 25%)
   Revenue per customer = frequency x AOV
   ------------------------------------------------------------ */
WITH segmented AS (
    SELECT CustomerID
         , COUNT(*)       AS orders
         , SUM(net_sales) AS revenue
         , NTILE(4) OVER (ORDER BY COUNT(*))       AS freq_q
         , NTILE(4) OVER (ORDER BY SUM(net_sales)) AS spend_q
    FROM v_sales_clean
    GROUP BY CustomerID
)
SELECT freq_q
     , spend_q
     , COUNT(*)               AS customers
     , ROUND(AVG(orders), 1)  AS avg_orders
     , ROUND(AVG(revenue), 2) AS avg_revenue
     , ROUND(SUM(revenue) * 100 / (SELECT SUM(revenue) FROM segmented), 2) AS revenue_share_pct
FROM segmented
GROUP BY freq_q, spend_q
ORDER BY freq_q, spend_q;
-- Result:
--   Customers are spread fairly evenly across the 16 segments (3,126 to 8,993 per cell);
--   the largest is (4,4) with 8,993 customers and 17.04% of revenue.
--   Average orders per customer range from 57.8 (frequency Q1) to 79.4 (Q4).
--   Average revenue per customer ranges from ~11.9K (spend Q1) to ~82.1K (spend Q4).
-- Insight:
--   Frequency and spend are only weakly linked: customers do not cluster on the diagonal.
--   Revenue per customer = orders x AOV. Orders vary far less than revenue,
--   so spend differences come mainly from AOV (how much per order), not from how often
--   customers buy. Every customer is a frequent buyer (57.8+ orders on average).
--   For CRM: retain the (4,4) segment with a loyalty programme; for high-spend, lower-frequency
--   customers, encourage more visits; for frequent, low-spend customers, grow basket value
--   (see 3.3). Data is simulated, so segment sizes are more even than in a real store.


/* ------------------------------------------------------------
   3.2 Repeat vs one-time customers by month
   Repeat = 2+ orders in the month; one-time = 1 order
   ------------------------------------------------------------ */
WITH customer_month AS (
    SELECT MONTH(SalesDate) AS sale_month
         , CustomerID
         , COUNT(*)       AS orders
         , SUM(net_sales) AS revenue
    FROM v_sales_clean
    WHERE has_sales_date = 1
    GROUP BY MONTH(SalesDate), CustomerID
)
SELECT sale_month
     , COUNT(*)                                                     AS active_customers
     , SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)                 AS repeat_customers
     , ROUND(AVG(CASE WHEN orders >= 2 THEN 1 ELSE 0 END) * 100, 2) AS repeat_rate_pct
     , ROUND(SUM(CASE WHEN orders >= 2 THEN revenue ELSE 0 END) * 100 / SUM(revenue), 2) AS repeat_revenue_share_pct
FROM customer_month
GROUP BY sale_month
ORDER BY sale_month;
-- Result:
--   Jan-Apr: all 98,759 customers (= every customer in the customers table) bought in every month,
--   and all of them placed 2+ orders: repeat rate 100%, repeat revenue share 100%.
--   May: repeat rate 95.76%, repeat revenue share 99.13%; May only has 9 days of data.
-- Insight:
--   Retention is not an issue: every customer buys repeatedly every month. The one-time group
--   is effectively empty, so the repeat branch of the KPI tree does not explain revenue differences.
--   The lower May rate is a partial-month effect, not customer loss.
--   CRM effort should focus on basket value (see 3.3) rather than retention.
--   A 100% monthly repeat rate is unrealistic and confirms the data is simulated.


/* ------------------------------------------------------------
   3.3 AOV and basket size by spend quartile
   AOV = UPT (basket size) x AUR
   ------------------------------------------------------------ */
WITH customer_spend AS (
    SELECT CustomerID
         , NTILE(4) OVER (ORDER BY SUM(net_sales)) AS spend_q
    FROM v_sales_clean
    GROUP BY CustomerID
)
SELECT c.spend_q
     , COUNT(*)                                       AS orders
     , ROUND(SUM(v.gross_sales) / COUNT(*), 2)        AS aov
     , ROUND(SUM(v.Quantity) / COUNT(*), 2)           AS upt
     , ROUND(SUM(v.gross_sales) / SUM(v.Quantity), 2) AS aur
FROM v_sales_clean v
JOIN customer_spend c ON v.CustomerID = c.CustomerID
GROUP BY c.spend_q
ORDER BY c.spend_q;
-- Result:
--   Orders are similar across spend quartiles (1.66M to 1.76M).
--   AUR is flat (50.32 to 51.41), while UPT rises from 3.66 (spend Q1) to 21.72 (Q4),
--   so AOV rises from 184.17 to 1,116.48.
-- Insight:
--   Basket size (UPT) is the main driver of AOV and therefore of customer spend.
--   High spenders do not buy more expensive items and place only slightly more orders
--   (about 6% more than spend Q1); they put far more items in each order. For Marketing, growing basket size is the key lever:
--   bundles, multi-buy offers and cross-sell for low-UPT customers (spend Q1-Q2).

/* Scenario 3 summary
   - Every customer buys every month (repeat rate 100% Jan-Apr), so retention is not an issue.
   - Visit frequency differs little between customers (57.8 to 79.4 orders on average)
     and is only weakly linked to spend.
   - Spend differences come from AOV, and AOV differences come from basket size (UPT),
     not price (AUR is flat at ~50).
   - KPI tree check: leaf 1 (repeat customers) is constant at 100%; leaf 2 (UPT) is the driver.
     Marketing should focus on increasing items per order.
*/


/* ============================================================
   Scenario 4: Salesperson performance
   ============================================================ */

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


/* ============================================================
   Scenario 5: Revenue by geography
   ============================================================ */

/* ------------------------------------------------------------
   5.1 + 5.2 + 5.3 Revenue, units and KPI drivers by city
   Net sales = customers x frequency x UPT x AUR x (1 - discount)
   Active rate is 100% in every city (all customers buy every month, see 3.2),
   so buying customers = registered customers.
   ------------------------------------------------------------ */

-- Check: how many countries do the 96 cities belong to?
SELECT COUNT(DISTINCT CountryID) AS countries FROM cities;
-- Result: 1. All 96 cities belong to the same country.
-- Decision: Country level is skipped; geography is analysed at city level only.

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
--   already active (see 3.2), growth in weaker cities must come from acquiring new customers
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
