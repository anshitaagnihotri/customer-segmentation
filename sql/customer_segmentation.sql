-- =====================================================================
-- Customer Segmentation & Revenue Intelligence (Chinook, SQLite)
-- Revenue = invoice_line.unit_price * invoice_line.quantity
-- =====================================================================

-- Q1: Who are the highest-spending customers?
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
       ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent
FROM customer c
JOIN invoice i       ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id  = il.invoice_id
GROUP BY c.customer_id, customer_name, c.country
ORDER BY total_spent DESC
LIMIT 10;
-- Insight: Frantisek Wichterlova (144.54) and Helena Holy (128.70), both from the Czech Republic,
-- are the top spenders, followed by Hugh O'Reilly (114.84) from Ireland. The top 10 customers
-- come from 8 different countries.

-- Q2: Who are the most frequent purchasers?
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
       COUNT(i.invoice_id) AS purchases,
       ROUND(SUM(i.total), 2) AS total_spent
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, customer_name, c.country
ORDER BY purchases DESC, total_spent DESC
LIMIT 10;
-- Insight: Frantisek Wichterlova is also the most frequent buyer with 18 purchases, ahead of
-- Madalena Sampaio (16) and Fernanda Ramos (15). The average customer made about 10 purchases.
-- Frequent buyers are not always the biggest spenders: Madalena Sampaio buys often but her
-- total is only 82.17.

-- Q3: Which customers have not purchased recently?
-- (No purchase in the last 180 days of the data. The data ends on 2020-12-30, so that date
-- is used as "today" instead of the real current date.)
WITH last_purchase AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, customer_name, c.country
)
SELECT customer_id, customer_name, country,
       DATE(last_purchase_date) AS last_purchase_date,
       CAST(julianday((SELECT MAX(invoice_date) FROM invoice)) - julianday(last_purchase_date) AS INTEGER) AS days_since_purchase
FROM last_purchase
WHERE julianday((SELECT MAX(invoice_date) FROM invoice)) - julianday(last_purchase_date) > 180
ORDER BY days_since_purchase DESC;
-- Insight: 16 of 59 customers (about 27%) have not bought in 6+ months. Daan Peeters (Belgium,
-- last purchase 2019-09-21, 466 days ago) is the longest inactive customer, followed by Kara
-- Nielsen (Denmark) and Bjorn Hansen (Norway). These customers are the right target for a
-- win-back campaign.

-- Q4: Which countries have the highest-value customers?
-- (Only countries with at least 2 customers are shown, so one customer cannot distort the average.)
WITH customer_spend AS (
    SELECT c.customer_id, c.country,
           SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, c.country
)
SELECT country,
       COUNT(*) AS customers,
       ROUND(AVG(total_spent), 2) AS avg_spend_per_customer,
       ROUND(SUM(total_spent), 2) AS total_revenue
FROM customer_spend
GROUP BY country
HAVING COUNT(*) >= 2
ORDER BY avg_spend_per_customer DESC;
-- Insight: Czech Republic customers spend the most on average (136.62 each), followed by
-- Portugal (92.56) and India (91.58). The USA has the most customers (13) and the highest total
-- revenue, but its average per customer is only 80.04, and Canada has the lowest average
-- (66.95). Big markets are not the same as high-value customers.

-- Q5: What is the average customer lifetime spending?
WITH customer_spend AS (
    SELECT c.customer_id, SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id
)
SELECT ROUND(AVG(total_spent), 2) AS avg_lifetime_spending,
       ROUND(MIN(total_spent), 2) AS min_spending,
       ROUND(MAX(total_spent), 2) AS max_spending
FROM customer_spend;
-- Insight: The average customer spent 79.82 in total, with spending ranging from 29.70 to
-- 144.54. The best customer is worth almost 5 times the weakest.

-- Q6: Which genres are most popular?
SELECT g.name AS genre, SUM(il.quantity) AS units_sold,
       RANK() OVER (ORDER BY SUM(il.quantity) DESC) AS popularity_rank
FROM genre g
JOIN track t         ON g.genre_id = t.genre_id
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY g.genre_id, g.name
ORDER BY units_sold DESC
LIMIT 10;
-- Insight: Rock is far ahead with 2,635 units, then Metal (619) and Alternative & Punk (492).
-- Rock alone is about 55% of all units sold, so demand is concentrated in rock-related genres.

-- Q7: Which artists generate the highest revenue?
SELECT ar.name AS artist, ROUND(SUM(il.unit_price * il.quantity), 2) AS revenue
FROM artist ar
JOIN album al        ON ar.artist_id = al.artist_id
JOIN track t         ON al.album_id  = t.album_id
JOIN invoice_line il ON t.track_id   = il.track_id
GROUP BY ar.artist_id, ar.name
ORDER BY revenue DESC
LIMIT 10;
-- Insight: Queen (190.08) and Jimi Hendrix (185.13) lead, followed by Nirvana and Red Hot Chili
-- Peppers (128.70 each) and Pearl Jam (127.71). Rock acts fill the entire top 10.

-- Q8: Which tracks are purchased most frequently?
SELECT t.name AS track, SUM(il.quantity) AS times_purchased
FROM track t
JOIN invoice_line il ON t.track_id = il.track_id
GROUP BY t.track_id, t.name
ORDER BY times_purchased DESC
LIMIT 10;
-- Insight: "War Pigs" was bought 31 times, more than double the next track (14 purchases).
-- One hit track stands out, while the rest of the catalogue sells in small numbers.

-- Q9a: Create customer segments (High, Medium, Low Value) - segment summary
-- High Value: spending >= 120% of the average. Medium Value: 80% to 120% of the average.
-- Low Value: below 80% of the average.
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, customer_name, c.country
),
segmented AS (
    SELECT *,
           CASE WHEN total_spent >= 1.2 * (SELECT AVG(total_spent) FROM customer_spend) THEN 'High Value'
                WHEN total_spent >= 0.8 * (SELECT AVG(total_spent) FROM customer_spend) THEN 'Medium Value'
                ELSE 'Low Value' END AS segment
    FROM customer_spend
)
SELECT segment,
       COUNT(*) AS customers,
       ROUND(SUM(total_spent), 2) AS revenue,
       ROUND(100.0 * SUM(total_spent) / (SELECT SUM(total_spent) FROM customer_spend), 2) AS pct_of_revenue,
       ROUND(AVG(total_spent), 2) AS avg_spend
FROM segmented
GROUP BY segment
ORDER BY avg_spend DESC;
-- Insight: 13 High Value customers (22%) bring 29.93% of revenue (avg 108.44 each). 37 Medium
-- Value customers bring 60.82% (avg 77.41). 9 Low Value customers bring only 9.25% (avg
-- 48.40). Revenue is not dominated by a few customers, but the High Value group earns about
-- 2.2 times more per head than the Low Value group.

-- Q9b: Customer-level segment list
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, customer_name, c.country
)
SELECT customer_id, customer_name, country, ROUND(total_spent, 2) AS total_spent,
       CASE WHEN total_spent >= 1.2 * (SELECT AVG(total_spent) FROM customer_spend) THEN 'High Value'
            WHEN total_spent >= 0.8 * (SELECT AVG(total_spent) FROM customer_spend) THEN 'Medium Value'
            ELSE 'Low Value' END AS segment
FROM customer_spend
ORDER BY total_spent DESC;
-- Insight: This list shows which segment each customer belongs to, so marketing can target
-- High Value customers with loyalty offers and Low Value customers with activation offers.

-- Q10: Rank customers by spending within each country
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, customer_name, c.country
)
SELECT country, customer_name, total_spent,
       RANK() OVER (PARTITION BY country ORDER BY total_spent DESC) AS rank_in_country
FROM customer_spend
ORDER BY country, rank_in_country;
-- Insight: Ranking inside each country shows the local best customer, for example Luis Goncalves
-- (Brazil, 108.90), Francois Tremblay (Canada, 99.99) and Frantisek Wichterlova (Czech
-- Republic, 144.54). Countries with a single customer have only a rank 1 customer. Use this
-- list to find local VIP customers for market-specific offers.

-- Q11: Find customers whose spending is above average
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, customer_name, c.country
)
SELECT customer_id, customer_name, country, ROUND(total_spent, 2) AS total_spent,
       ROUND(total_spent - (SELECT AVG(total_spent) FROM customer_spend), 2) AS above_average_by
FROM customer_spend
WHERE total_spent > (SELECT AVG(total_spent) FROM customer_spend)
ORDER BY total_spent DESC;
-- Insight: 25 of 59 customers (about 42%) spend above the 79.82 average. The top customer is
-- 64.72 above average. These customers are the main group for loyalty and upsell offers.

-- Q12: Find the top 3 customers in each country
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           ROUND(SUM(il.unit_price * il.quantity), 2) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, customer_name, c.country
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY country ORDER BY total_spent DESC) AS rn
    FROM customer_spend
)
SELECT country, customer_name, total_spent, rn AS rank_in_country
FROM ranked
WHERE rn <= 3
ORDER BY country, rn;
-- Insight: 15 of the 24 countries have only one customer, so they appear once with rank 1.
-- Larger markets such as Brazil, Canada and the USA show a clear top 3. These lists show who
-- to nurture in each market.

-- Q13: Identify customers who have purchased from multiple genres
SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
       COUNT(DISTINCT t.genre_id) AS genres_purchased
FROM customer c
JOIN invoice i       ON c.customer_id = i.customer_id
JOIN invoice_line il ON i.invoice_id  = il.invoice_id
JOIN track t         ON il.track_id   = t.track_id
GROUP BY c.customer_id, customer_name, c.country
HAVING COUNT(DISTINCT t.genre_id) > 1
ORDER BY genres_purchased DESC, customer_name;
-- Insight: All 59 customers bought from more than one genre. The least varied customer
-- bought from 5 genres and the most varied (Leonie Kohler, Germany) from 14. The audience is
-- broad rather than genre-loyal, so cross-genre recommendations are likely to work.

-- Q14: Calculate each customer's percentage contribution to total revenue
WITH customer_spend AS (
    SELECT c.customer_id, c.first_name || ' ' || c.last_name AS customer_name, c.country,
           SUM(il.unit_price * il.quantity) AS total_spent
    FROM customer c
    JOIN invoice i       ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id  = il.invoice_id
    GROUP BY c.customer_id, customer_name, c.country
)
SELECT customer_id, customer_name, country, ROUND(total_spent, 2) AS total_spent,
       ROUND(100.0 * total_spent / SUM(total_spent) OVER (), 2) AS pct_of_total_revenue
FROM customer_spend
ORDER BY total_spent DESC;
-- Insight: No customer contributes more than 3.07% (Frantisek Wichterlova), and the weakest
-- contributes 0.63%. The top 10 customers together contribute about 23.7% of revenue, so the
-- business has low dependence on any single customer.

-- Q15: Calculate cumulative revenue using a window function
WITH monthly AS (
    SELECT strftime('%Y-%m', i.invoice_date) AS month,
           SUM(il.unit_price * il.quantity) AS revenue
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY month
)
SELECT month, ROUND(revenue, 2) AS monthly_revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS cumulative_revenue
FROM monthly
ORDER BY month;
-- Insight: Revenue builds up at a steady pace of roughly 98 per month. The running total reaches
-- 1,201.86 by the end of 2017, about 2,349 by the end of 2018, about 3,571 by the end of 2019
-- and 4,709.43 by December 2020. The near-straight line shows stable but flat growth.

-- Q16: Which month has the highest revenue?
WITH monthly AS (
    SELECT strftime('%Y-%m', i.invoice_date) AS month,
           SUM(il.unit_price * il.quantity) AS revenue
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY month
)
SELECT month, ROUND(revenue, 2) AS revenue
FROM monthly
ORDER BY revenue DESC
LIMIT 1;
-- Insight: January 2018 is the best month with 183.15 in revenue, well above the typical
-- month (about 98). One strong month does not make a seasonal pattern, because the other
-- years do not repeat it.
