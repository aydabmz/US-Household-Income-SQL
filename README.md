# US Household Income – SQL Data Cleaning & Exploration
![SQL](https://img.shields.io/badge/SQL-MySQL-blue?logo=mysql&logoColor=white)

**Skills Used:** SQL (MySQL), Data Cleaning, Data Exploration, Window Functions, Joins, Aggregations, EDA, Data Quality Checks

This project was completed as part of **Alex Freberg’s SQL course on AnalystBuilder**.  
It focuses on cleaning and exploring the **US Household Income** dataset, which includes two related tables: income data and statistical summaries.  
The work involved removing duplicates, correcting small data quality issues, verifying data consistency between tables, and performing exploratory data analysis (EDA) to uncover income patterns by **state**, **city**, and **area type**.

---

## Key Steps

### 1. Data Quality Checks & Duplicate Removal
- Identified duplicate `id` values using `GROUP BY` and `HAVING`.
- Used `ROW_NUMBER()` and a MySQL-safe self-join deletion method to remove duplicates in batches.
- Verified that the statistics table contained no duplicates.

### 2. Small Data Corrections
- Fixed typos in state names (`georia` → `Georgia`, `alabama` → `Alabama`).
- Standardized values in the `Type` column (`Boroughs` → `Borough`).
- Filled missing `Place` values based on county and city context.

### 3. Data Integrity Verification
- Checked for IDs present in one table but not the other.
- Ensured only matched records were used for analysis.

### 4. Exploratory Data Analysis (EDA)
- Ranked states by total land and water area.
- Compared average **mean** and **median** incomes for top and bottom states.
- Explored income differences by **Type** (city, village, borough) and filtered out sparse categories.
- Identified top-earning cities within each state.

---

## Insights
- **Alaska** leads in both land and water area totals.
- **District of Columbia** has the highest average mean income — nearly **2×** Mississippi’s.
- Sparse categories like *Municipality* can distort averages if not filtered.
- City-level analysis highlights high-income areas even in lower-income states.

---

## Repository Contents
- `us_household_income_cleaning_eda.sql` → Complete SQL code with professional, detailed comments.
- `USHouseholdIncome.csv` and `USHouseholdIncome_Statistics.csv` → Original datasets.

---

## Next Steps
- Build Tableau or Power BI dashboards to visualize geographic income patterns.
- Enrich the dataset with census or economic data for deeper analysis.
