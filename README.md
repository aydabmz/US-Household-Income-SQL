# US Household Income – SQL Data Cleaning & Exploration  
![SQL](https://img.shields.io/badge/SQL-MySQL-blue?logo=mysql&logoColor=white)  

**Skills Used:** SQL (MySQL), Data Cleaning, Data Exploration, Window Functions, Joins, Aggregations, EDA, Data Quality Checks  

This project was completed as part of *Alex Freberg’s SQL course on AnalystBuilder*.  
It applies real-world data cleaning and exploratory analysis techniques to the **US Household Income** dataset.  
The work focuses on removing duplicates, correcting data quality issues, standardizing values, and exploring patterns by state and area type.  

---

## Key Steps  

### 1. Duplicate Removal  
- Identified duplicate `id` values using `GROUP BY` and `HAVING`.  
- Applied `ROW_NUMBER()` and a MySQL-safe self-join method to delete duplicates in small batches.  

### 2. Data Quality Fixes  
- Corrected spelling errors in `State_Name`.  
- Standardized `Type` values (e.g., “Boroughs” → “Borough”).  
- Filled in missing `Place` based on contextual matches.  

### 3. Exploratory Data Analysis (EDA)  
- Compared total land and water area by state.  
- Checked table consistency between `US_Household_Income` and `US_Household_Income_Statistics`.  
- Calculated average mean and median incomes by state and type.  
- Identified top and bottom states by average mean income.  
- Examined income variation by area type, filtering for well-represented categories.  

---

## Insights  
- **Alaska** leads both in total land and water area.  
- **District of Columbia** has nearly double the mean income of Mississippi, showing wide income disparity.  
- Sparse categories (like “Municipality”) can distort averages — filtering improves reliability.  

---

## Repository Contents  
- `us_household_income_cleaning_eda.sql` → Complete SQL code with professional, detailed comments.  
- `USHouseholdIncome.csv` and `USHouseholdIncome_Statistics.csv` → Original datasets.  

---

## Next Steps  
- Create state-level and city-level income visualizations in Tableau or Power BI.  
- Explore correlations between geographic factors and income levels.  

---

*Data provided for learning purposes (course materials). Credit: AnalystBuilder / Alex Freberg.*
