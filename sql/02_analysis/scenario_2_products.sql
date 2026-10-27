/* ============================================================
   02_analysis/scenario_2_products.sql  (MySQL)
   Scenario 2: Product ranking and classification
   Source: view v_sales_clean (built in 01_cleaning/10_v_sales_clean.sql)
   Rules:
   - Totals use all rows; time-based queries use WHERE has_sales_date = 1.
   - May 2018 has only 9 days of data, so months are compared per day.
   ============================================================ */

USE fmcg_project;

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

/* ------------------------------------------------------------
   2.4 Pareto / ABC analysis of products by net revenue
   A = top 80% of cumulative revenue, B = next 15%, C = last 5%
   ------------------------------------------------------------ */
CREATE OR REPLACE VIEW v_product_abc AS
WITH product_revenue AS (
    SELECT
          v.ProductID
        , p.Price
        , SUM(v.net_sales) AS revenue
    FROM v_sales_clean v
    JOIN products p ON v.ProductID = p.ProductID
    GROUP BY v.ProductID, p.Price
), cumulative AS (
    SELECT
          *
        , SUM(revenue) OVER (ORDER BY revenue DESC, ProductID)
          / SUM(revenue) OVER ()                       AS cum_share
    FROM product_revenue
)
SELECT
      *
    , CASE WHEN cum_share <= 0.80 THEN 'A'
           WHEN cum_share <= 0.95 THEN 'B'
           ELSE 'C' END                                AS abc_class
FROM cumulative;

-- Summary: share of products vs share of revenue per class
SELECT
      abc_class
    , COUNT(*)                                                    AS products
    , ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1)            AS pct_products
    , ROUND(SUM(revenue) / SUM(SUM(revenue)) OVER () * 100, 1)    AS pct_revenue
    , ROUND(AVG(Price), 2)                                        AS avg_price
FROM v_product_abc
GROUP BY abc_class
ORDER BY abc_class;

-- Result: A = 252 products (55.8%) bring 79.9% of revenue, avg price 72.81.
--   B = 96 products (21.2%) bring 15.0%, avg price 35.85.
--   C = 104 products (23.0%) bring 5.1%, avg price 11.27.

-- Insight: Revenue is only moderately concentrated, not a classic 80/20:
--   it takes 56% of products to reach 80% of revenue.
--   Average price falls sharply from A to C, while volume is almost equal
--   across products (2.2), so ABC class here reflects price level, not demand.
--   Class C items should be reviewed on pricing, not delisted for low sales.
--   Revenue per product falls almost linearly from top to bottom, with no
--   long tail, which is why the cumulative curve rises slowly.

-- For the Tableau Pareto chart (export to CSV)
SELECT * FROM v_product_abc ORDER BY cum_share;

/* Scenario 2 summary
   - All 452 products sold; units per product are nearly equal (1.05x range).
   - Revenue differences come from price, not volume (2,213x revenue range);
     the bottom 5 are low-price items, not slow movers.
   - Class has little impact: revenue is split ~1/3 each, with SKU count
     and AUR offsetting each other.
   - KPI tree check: SKU sold rate = 100%; the hypothesis that differences
     come from units per SKU is rejected. AUR is the driver.
*/
