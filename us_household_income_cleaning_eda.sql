-- US Household Income — Data Cleaning & EDA
/*
Project: US Household Income — Data Cleaning & EDA
Goal: Clean and prepare the US Household Income dataset by removing duplicates,
      correcting small data-quality issues (e.g., typos, inconsistent labels),
      and ensuring the data is ready for analysis. 
      Perform exploratory data analysis (EDA) to uncover patterns and trends
      in income statistics by state, city, and area type, and to explore how
      factors like land/water area relate to income distributions.
*/


-- Quick peek at both tables
SELECT * FROM US_Project.USHouseholdIncome;
SELECT * FROM US_Project.ushouseholdincome_statistics;

-- Rename tables (one-time setup)
ALTER TABLE US_Project.USHouseholdIncome                RENAME TO US_Household_Income;
ALTER TABLE US_Project.ushouseholdincome_statistics     RENAME TO US_Household_Income_Statistics;

-- Basic row counts
SELECT COUNT(id) AS rows_income      FROM US_Household_Income;
SELECT COUNT(id) AS rows_statistics  FROM US_Household_Income_Statistics;


-- ============================
-- 1) Identify & remove duplicates
-- ============================

-- Find duplicated IDs in the income table
SELECT id, COUNT(*) AS cnt
FROM US_Household_Income
GROUP BY id
HAVING COUNT(*) > 1;
-- Result: 7 duplicated IDs

-- Mark duplicate rows (keep the first per id). We cannot filter the window alias in the same SELECT level.
SELECT *
FROM (
    SELECT
        row_id,
        id,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS row_num
    FROM US_Household_Income
) d
WHERE row_num > 1;

-- Delete duplicates (PostgreSQL / SQL Server style)
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

-- Delete duplicates (MySQL-safe pattern, in batches)
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


-- Check duplicates in the stats table (none found)
SELECT id, COUNT(*) AS cnt
FROM US_Household_Income_Statistics
GROUP BY id
HAVING COUNT(*) > 1;


-- ============================
-- 2) Small data-quality fixes
-- ============================

-- Spot obvious spelling issues in state names
SELECT DISTINCT State_Name FROM US_Household_Income;

-- Normalize a few mis-typed values
UPDATE US_Household_Income SET State_Name = 'Georgia' WHERE State_Name = 'georia';
UPDATE US_Household_Income SET State_Name = 'Alabama' WHERE State_Name = 'alabama';

-- Inspect a specific county
SELECT *
FROM US_Household_Income
WHERE County = 'Autauga County'
ORDER BY row_id;

-- Fill a missing place based on surrounding context (manual rule)
UPDATE US_Household_Income
SET Place = 'Autaugaville'
WHERE County = 'Autauga County'
  AND City   = 'Vinemont';

-- Standardize “Type” values
SELECT Type, COUNT(*) AS cnt
FROM US_Household_Income
GROUP BY Type;

-- Merge obvious near-duplicates (Boroughs -> Borough). CPD vs. CDP is ambiguous—verify with source before changing.
UPDATE US_Household_Income
SET Type = 'Borough'
WHERE Type = 'Boroughs';

-- Check water/land area anomalies (zeros are common; no NULL/'' found in AWater)
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

-- 3.1 Land vs. Water by state (top totals)
-- Question: Which states account for the most total land/water area in this dataset?
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

-- 3.2 Key integrity check between Income and Statistics
-- Use an anti-join to find IDs in one table but not the other (the original INNER JOIN with WHERE u.id IS NULL always returns 0).
-- IDs in Income without a matching Statistics row:
SELECT u.id
FROM US_Household_Income u
LEFT JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.id IS NULL;

-- IDs in Statistics without a matching Income row:
SELECT us.id
FROM US_Household_Income_Statistics us
LEFT JOIN US_Household_Income u
  ON u.id = us.id
WHERE u.id IS NULL;

-- If any appear above, decide whether to fix upstream or exclude them during analysis for consistency.


-- 3.3 Join both tables for income distribution analysis
-- Filter out rows where summary stats are zero (often placeholders/no data).
SELECT *
FROM US_Household_Income u
INNER JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0;

-- 3.4 Average Mean/Median by state (lowest/highest)
-- These views highlight relative income differences across states.
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
-- Interpretation: Top-5 states by average mean income (e.g., District of Columbia, Connecticut, New Jersey, Maryland, Massachusetts).
-- DC’s average is roughly 2× Mississippi’s, illustrating wide dispersion.

-- 3.5 Compare rank by median (can differ from mean if distributions are skewed)
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

-- 3.6 Income by “Type” (city/village/etc.), then handle sparse categories
SELECT Type,
       ROUND(AVG(us.Mean),   1) AS avg_mean,
       ROUND(AVG(us.Median), 1) AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY Type
ORDER BY avg_mean DESC;

-- Note: “Municipality” shows very high income but has tiny sample size. Check category counts before trusting conclusions.
SELECT Type,
       COUNT(*)                         AS n_rows,
       ROUND(AVG(us.Mean),   1)         AS avg_mean,
       ROUND(AVG(us.Median), 1)         AS avg_median
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
WHERE us.Mean <> 0
GROUP BY Type
ORDER BY avg_mean DESC;

-- Filter out sparse types to reduce noise (example threshold: > 100 rows)
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
-- Cleaner view: focuses on well-represented area types and more reliable averages.

-- 3.7 Drill down by state & city
SELECT u.State_Name,
       u.City,
       ROUND(AVG(us.Mean), 1) AS avg_mean
FROM US_Household_Income u
JOIN US_Household_Income_Statistics us
  ON u.id = us.id
GROUP BY u.State_Name, u.City
ORDER BY avg_mean DESC;
-- Use this to spot high-earning cities within each state; great input for maps or bar charts.
