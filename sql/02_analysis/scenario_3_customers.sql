/* ============================================================
   02_analysis/scenario_3_customers.sql  (MySQL)
   Scenario 3: Customer behaviour and segmentation
   Source: view v_sales_clean (built in 01_cleaning/10_v_sales_clean.sql)
   Rules:
   - Totals use all rows; time-based queries use WHERE has_sales_date = 1.
   - May 2018 has only 9 days of data, so months are compared per day.
   ============================================================ */

USE fmcg_project;

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
