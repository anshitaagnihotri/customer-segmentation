# Customer Segmentation & Revenue Intelligence (SQL)

A customer intelligence analysis on the Chinook digital media store, built with SQL. It identifies valuable customers, purchasing patterns, customer segments and revenue contribution.

## 1. Business Problem

A digital media company wants to build a customer intelligence system from its sales database. The goal is to identify:

- Valuable customers
- Purchasing patterns
- Customer segments
- Revenue contribution

## 2. Dataset

- **Chinook database** (SQLite), source: https://github.com/lerocha/chinook-database
- File in this repo: `chinook.db`
- 59 customers from 24 countries, 614 invoices, 3,503 tracks
- Period covered: January 2017 to December 2020
- Revenue is calculated as `invoice_line.unit_price * invoice_line.quantity`

### Database setup

The database is a single SQLite file, so no import is needed.

1. Clone the repo: `git clone https://github.com/anshitaagnihotri/customer-segmentation.git`
2. Open the folder in VS Code.
3. Install the **SQLTools** and **SQLTools SQLite** extensions (SQLTools needs Node.js; enable `sqltools.useNodeRuntime`).
4. Add a new SQLite connection that points to `chinook.db`.
5. Open `sql/customer_segmentation.sql`, select a query and run it with **Run on active connection**.

Alternative: `sqlite3 chinook.db < sql/customer_segmentation.sql`

## 3. Database Schema

```
artist -> album -> track -> invoice_line -> invoice -> customer
track -> genre
```

| Table | Purpose |
|---|---|
| customer | Customer details and country |
| invoice / invoice_line | Each bill and the tracks sold on it |
| track / album / artist / genre | Music catalogue |

## 4. Business Questions

1. Who are the highest-spending customers?
2. Who are the most frequent purchasers?
3. Which customers have not purchased recently?
4. Which countries have the highest-value customers?
5. What is the average customer lifetime spending?
6. Which genres are most popular?
7. Which artists generate the highest revenue?
8. Which tracks are purchased most frequently?
9. Create customer segments (High, Medium, Low Value).
10. Rank customers by spending within each country.
11. Find customers whose spending is above average.
12. Find the top 3 customers in each country.
13. Identify customers who have purchased from multiple genres.
14. Calculate each customer's percentage contribution to total revenue.
15. Calculate cumulative revenue using a window function.
16. Identify the month with the highest revenue.

## 5. SQL Concepts Used

- Customer segmentation with `CASE WHEN`
- CTEs (`WITH`) and subqueries
- Window functions: `RANK`, `ROW_NUMBER`, `SUM() OVER` (running total and percentage of total)
- Ranking and top-N per group (`PARTITION BY`)
- Aggregation with `GROUP BY` and `HAVING`
- Multi-table JOINs (up to 5 tables)
- Date functions (`strftime`, `julianday`, `MAX` date)
- String concatenation

## 6. SQL Queries

All 16 queries, each followed by a short insight, are in [`sql/customer_segmentation.sql`](sql/customer_segmentation.sql).

Segment rules used in Q9: **High Value** = spending at least 120% of the average, **Medium Value** = 80% to 120% of the average, **Low Value** = below 80% of the average. "Recent" in Q3 means a purchase in the last 180 days of the data (the data ends on 2020-12-30).

## 7. Key Findings

- **Top customers:** Frantisek Wichterlova (144.54) and Helena Holy (128.70), both from the Czech Republic, lead the spending ranking. The top 10 customers come from 8 countries and contribute about 23.7% of revenue.
- **Frequent buyers:** Frantisek Wichterlova also buys most often (18 purchases). The average customer made about 10 purchases, and frequency does not always mean high spending.
- **Inactive customers:** 16 of 59 customers (about 27%) have not bought in the last 6 months of the data. Daan Peeters (Belgium) has been inactive the longest (466 days).
- **High-value countries:** Czech Republic customers spend the most on average (136.62), while the USA has the most customers (13) but only 80.04 per customer. Canada has the lowest average (66.95).
- **Average lifetime spending is 79.82**, ranging from 29.70 to 144.54.
- **Segments:** 13 High Value customers (22%) bring 29.93% of revenue, 37 Medium Value customers bring 60.82% and 9 Low Value customers bring 9.25%.
- **Above-average customers:** 25 of 59 customers (about 42%) spend above the average.
- **Popular music:** Rock is the top genre by far (2,635 units, about 55% of all units). Queen (190.08) and Jimi Hendrix (185.13) are the top artists, and "War Pigs" is the most purchased track (31 purchases, more than double the next).
- **Broad tastes:** All 59 customers bought from more than one genre (between 5 and 14 genres each).
- **Low concentration:** No customer contributes more than 3.07% of revenue, so the business does not depend on a few customers.
- **Steady, flat growth:** Revenue built up at roughly 98 per month to a total of 4,709.43. The best month was January 2018 (183.15).

## 8. Business Recommendations

1. **Run a win-back campaign** for the 16 customers inactive for 6+ months, starting with the ones who spent the most before they stopped.
2. **Reward the 13 High Value customers** with loyalty offers or early access, because this group earns about 2.2 times more per head than Low Value customers.
3. **Activate the 9 Low Value customers** with small discounts or personalised recommendations, to move them into the Medium segment.
4. **Use cross-genre recommendations**, since every customer already buys from several genres. Suggest rock-adjacent genres to existing rock buyers.
5. **Look at markets by value per customer, not only by total revenue.** Czech Republic, Portugal and India have the highest-value customers, so they are good candidates for acquisition campaigns, while the USA and Canada may need upsell offers.
6. **Promote proven hits and top artists** (for example "War Pigs", Queen and Jimi Hendrix) in recommendations and the homepage.

## Project Structure

```
customer-segmentation/
├── chinook.db
├── sql/
│   └── customer_segmentation.sql
└── README.md
```

## Tools

SQLite, SQL, VS Code (SQLTools), Git and GitHub.
