-- US Household Income — Data Cleaning & EDA
/*
Project: US Household Income — Data Cleaning & EDA
Goal: Clean and prepare the US Household Income dataset by removing duplicates,
      correcting small data-quality issues (e.g., typos, inconsistent labels),
      and ensuring the data is ready for analysis.
      Perform exploratory data analysis (EDA) to uncover patterns and trends
      in income statistics by state, city, and area type, and to explore how
      land/water area may relate to income distributions.

Based on: Alex Freberg’s SQL Course (AnalystBuilder)
Skills: SQL (MySQL), Data Cleaning, Data Quality Checks, Window Functions, Joins, Aggregations, EDA
*/

-- Quick peek at both tables
SELECT * FROM US_Project.USHouseholdIncome;
SELECT * FROM US_Project.ushouseholdincome_statistics;

-- Rename tables (one-time setup)
ALTER TABLE US_Project.USHouseholdIncome            RENAME TO US_Household_Income;
ALTER TABLE US_Project.ushouseholdincome_statistics RENAME TO US_Household_Income_Statistics;

-- Basic row counts
SELECT COUNT(id) AS rows_income     FROM US_Household_Income;
SELECT COUNT(id) AS rows_statistics FROM US_Household_Income_Statistics;


-- ============================
-- 1) Identify & remove duplicates
-- ============================

-- 1.1 Find IDs that appear more than once (duplicate keys).
SELECT id, COUNT(*) AS cnt
FROM US_Household_Income
GROUP BY id
HAVING COUNT(*) > 1;
-- Result example: 7 duplicated IDs

-- 1.2 Label duplicate rows using ROW_NUMBER() (keep the first per id).
-- Note: We use a subquery because WHERE is evaluated before window functions.
SELECT *
FROM (
  SELECT
    row_id,
    id,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS row_num
  FROM US_Household_Income
) d
WHERE row_num > 1;

-- 1.3 Delete duplicates (PostgreSQL / SQL Server style).
DELETE FROM US_Household_Income
WHERE row_id IN (
  SELECT row_id
  FROM (
    SELECT
      row_id,
      id,
      ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS row_num
    FROM US_Household_Income
  ) d
  WHERE row_num > 1
);

-- 1.4 Delete duplicates (MySQL-safe pattern, in batches).
DELETE FROM US_Household_Income
WHERE row_id IN (
  SELECT row_id
  FROM (
    SELECT t1.row_id
    FROM US_Household_Income t1
    JOIN US_Household_Income t2
      ON t1.id = t2.id
     AND t1.row_id > t2.row_id      -- keeps the smallest row_id per id
    ORDER BY t1.row_id
    LIMIT 10000                      -- run repeatedly until 0 rows deleted
  ) AS sub
);
/*
Removes duplicate rows in small batches (10,000 at a time).
For each id, keeps the row with the smallest row_id and deletes the rest.
The self-join flags duplicates as “same id, higher row_id”.
The extra subquery is required in MySQL to avoid the
"target table for update" error when deleting from a table you also select from.
Run this multiple times until it affects 0 rows.
*/

-- 1.5 Verify duplicates in the stats table (expect none).
SELECT id, COUNT(*) AS cnt
FROM US_Household_Income_Statistics
GROUP BY id
HAVING COUNT(*) > 1;


-- ============================
-- 2) Small data-quality fixes
-- ============================

-- 2.1 Scan for inconsistent state names (typos / case).
SELECT DISTINCT State_Name FROM US_Household_Income;

-- 2.2 Normalize obvious misspellings.
UPDATE US_Household_Income SET State_Name = 'Georgia' WHERE State_Name = 'georia';
UPDATE US_Household_Income SET State_Name = 'Alabama' WHERE State_Name = 'alabama';

-- 2.3 Inspect a specific county for context before targeted fixes.
SELECT *
FROM US_Household_Income
WHERE County = 'Autauga County'
ORDER BY row_id;

-- 2.4 Fill a missing Place value using surrounding context (manual rule).
UPDATE US_Household_Income
SET Place = 'Autaugaville'
WHERE County = 'Autauga County'
  AND City   = 'Vinemont';

-- 2.5 Review and standardize “Type” values (merge near-duplicates).
SELECT Type, COUNT(*) AS cnt
FROM US_Household_Income
GROUP BY Type;

-- Boroughs -> Borough; (Note: CPD vs CDP is ambiguous—confirm with source before changing.)
UPDATE US_Household_Income
SET Type = 'Borough'
WHERE Type = 'Boroughs';

-- 2.6 Check land/water area anomalies (zeros are common placeholders).
SELECT ALand, AWater
FROM US_Household_Income
WHERE AWater = 0 OR AWater = '' OR AWater IS NULL;

SELECT DISTINCT AWater
FROM US_Household_Income
WHERE AWater = 0 OR AWater = '' OR AWater IS NULL;

-- Same check for ALand
SELECT ALand, AWater
FROM US_Household_Income
WHERE ALand = 0 OR ALand = '' OR ALand IS NULL;

-- Note: Data appears largely clean; only minimal normalization needed.


-- ============================
-- 3) Exploratory Data Analysis (EDA)
-- ============================

-- 3.1 Identify states with the largest total land and water area.
SELECT State_Name, SUM(ALand) AS sum_land, SUM(AWater) AS sum_water
FROM US_Household_Income
GROUP BY State_Name
ORDER BY sum_land DESC
LIMIT 10;
-- Insight: Alaska has the largest land total, followed by Texas and Oregon.

SELECT State_Name, SUM(ALand) AS sum_land, SUM(AWater) AS sum_water
FROM US_Household_Income
GROUP BY State_Name
ORDER BY sum_water DESC
LIMIT 10;
-- Insight: Alaska also leads in water area, followed by Michigan and Texas.

-- 3.2 Verify key integrity between the Income and Statistics tables (anti-joins).
-- IDs present in Income but missing in Statistics:
SELECT u.id
FROM US_Household_Income u
LEFT JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.id IS NULL;

-- IDs present in Statistics but missing in Income:
SELECT us.id
FROM US_Household_Income_Statistics us
LEFT JOIN US_Household_Income u
  ON u.id = us.id
WHERE u.id IS NULL;

-- If any IDs appear above, consider fixing upstream or excluding during analysis.

-- 3.3 Build an analysis-ready join of Income with Statistics (filter out zero stats).
SELECT *
FROM US_Household_Income u
INNER JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0;

-- 3.4 Compare states by average household income (Mean and Median) to find bottom performers.
SELECT u.State_Name,
       ROUND(AVG(us.Mean),   1) AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY u.State_Name
ORDER BY avg_mean
LIMIT 5;
-- Interpretation: Bottom-5 states by average mean income (e.g., Puerto Rico, Mississippi, Arkansas, West Virginia, Alabama).

-- 3.5 Compare states by average household income (Mean and Median) to find top performers.
SELECT u.State_Name,
       ROUND(AVG(us.Mean),   1) AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY u.State_Name
ORDER BY avg_mean DESC
LIMIT 5;
-- Interpretation: Top-5 states (e.g., District of Columbia, Connecticut, New Jersey, Maryland, Massachusetts).
-- DC’s average is roughly 2× Mississippi’s, illustrating wide dispersion.

-- 3.6 Rank states by median income (less sensitive to skew than mean).
SELECT u.State_Name,
       ROUND(AVG(us.Mean),   1) AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY u.State_Name
ORDER BY avg_median DESC;

SELECT u.State_Name,
       ROUND(AVG(us.Mean),   1) AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY u.State_Name
ORDER BY avg_median;
-- Guideline: When avg_median ≈ avg_mean, incomes are more evenly spread; big gaps suggest skew/outliers.

-- 3.7 Compare income by area “Type” (City, Village, Borough, etc.) and check sample sizes.
SELECT Type,
       ROUND(AVG(us.Mean),   1) AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY Type
ORDER BY avg_mean DESC;

-- Sample-size context for each Type (avoid over-interpreting tiny categories).
SELECT Type,
       COUNT(*)                 AS n_rows,
       ROUND(AVG(us.Mean), 1)   AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY Type
ORDER BY avg_mean DESC;

-- Focus on well-represented Types only (example threshold: > 100 rows).
SELECT Type,
       COUNT(*)                 AS n_rows,
       ROUND(AVG(us.Mean), 1)   AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY Type
HAVING COUNT(*) > 100
ORDER BY avg_mean DESC;
-- Cleaner view: focuses on reliable averages and reduces noise from sparse categories.

-- 3.8 Drill down to state–city level to surface top-earning cities.
SELECT u.State_Name,
       u.City,
       ROUND(AVG(us.Mean), 1) AS avg_mean
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
GROUP BY u.State_Name, u.City
ORDER BY avg_mean DESC;
-- Useful for maps or bar charts to highlight city-level standouts within each state.
