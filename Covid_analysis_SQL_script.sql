-------------------------------------------------------
--	Source : https://ourworldindata.org/covid-deaths
-------------------------------------------------------

--SELECT TOP 10 * FROM [dbo].[covid-data]

-------------------------------------------
--	What is the total number of deaths
SELECT FORMAT(SUM(new_deaths), '#,0') AS Total_Deaths
FROM [dbo].[covid-data]

----------------------------------------------------------------------
--	 As we see, the number is too high - over 20M. We have to find out the reason 
--	--> there is some data duplication. We may solve it by filtering out OWID from iso_code
SELECT FORMAT(SUM(new_deaths), '#,0') AS Total_Deaths
FROM [dbo].[covid-data]
WHERE LOWER(iso_code) NOT LIKE '%owid%'

-------------------------------------------------
--	What is the total number of deaths per country
--	Order from highes to Lowest
SELECT [location], FORMAT(SUM(new_deaths), '#,0') AS Total_Deaths
FROM [dbo].[covid-data]
WHERE LOWER(iso_code) NOT LIKE '%owid%'
GROUP BY [location]
ORDER BY SUM(new_deaths) DESC

-----------------------------------------------------
--	Now, let's see what is the percentage of death toll
;WITH CTE_Total_Deaths AS (
	SELECT SUM(new_deaths) AS Total_Deaths
	FROM [dbo].[covid-data]
	WHERE LOWER(iso_code) NOT LIKE '%owid%'
	),
	CTE_Death_by_Country AS (
	SELECT [location], SUM(new_deaths) AS Total_Deaths
	FROM [dbo].[covid-data]
	WHERE LOWER(iso_code) NOT LIKE '%owid%'
	GROUP BY [location]
	--ORDER BY SUM(new_deaths) DESC
	)
SELECT *, FORMAT(CAST(Country.Total_Deaths AS FLOAT) / Tot.Total_Deaths * 100, '#,0.0')  AS Death_Pct
FROM CTE_Death_by_Country AS Country, CTE_Total_Deaths AS Tot
ORDER BY 
	Country.Total_Deaths DESC

-------------------------------------------------------------
--	Another option to get the same result
;WITH CTE_Data_Set AS (
	SELECT [location], new_deaths, 
		SUM(new_deaths) OVER() AS Tot_Deaths
	FROM [dbo].[covid-data]
	WHERE LOWER(iso_code) NOT LIKE '%owid%'
	)
SELECT 
	[location],
	SUM(new_deaths) AS Total_Deaths,
	Tot_Deaths,
	FORMAT(SUM(new_deaths) / CAST(Tot_Deaths AS FLOAT) * 100,'#,0.0')  AS Death_Pct
FROM CTE_Data_Set
GROUP BY
	[location], Tot_Deaths
ORDER BY 
	SUM(new_deaths) DESC

-------------------------------------------------------------------------
--	What was running total of deaths toll over time (Month over Month)
;WITH CTE_Data_Set AS (
	SELECT
		CONVERT(VARCHAR(7), [date], 126) AS Year_Month,  
		SUM(new_deaths) AS Tot_Deaths
	FROM
		[dbo].[covid-data]
	WHERE
		LOWER(iso_code) NOT LIKE '%owid%'
	GROUP BY 
		CONVERT(VARCHAR(7), [date], 126)
	)
SELECT 
	Year_Month,
	FORMAT(SUM(Tot_Deaths) OVER(ORDER BY Year_Month), '#,0') AS Running_tot_Deaths
FROM CTE_Data_Set
ORDER BY
	Year_Month

--	SELECT TOP 10 * FROM [dbo].[covid-data]
-------------------------------------------------------------------------
--	What countries had the highest rate of covid cases as % of population
SELECT 
	[location],
	SUM(new_cases) AS Covid_Cases_Sum,
	SUM(new_deaths) AS Deaths_Cases_Sum,
	MAX([population]) AS [Population],
	FORMAT(CAST(SUM(new_cases) AS FLOAT) / MAX([population]) * 100, '#,0.0') AS [rate of covid cases as % of population],
	FORMAT(CAST(SUM(new_deaths) AS FLOAT) / MAX([population]) * 100, '#,0.000') AS [rate of Death cases as % of population]
FROM [dbo].[covid-data]
WHERE
	LOWER(iso_code) NOT LIKE '%owid%'
GROUP BY
	[location]
ORDER BY
	(CAST(SUM(new_cases) AS FLOAT) / MAX([population]) * 100) DESC,
	(CAST(SUM(new_deaths) AS FLOAT) / MAX([population]) * 100) DESC
;
-- Let's define a few KPI of how efficient a goverment was:
--		let's say, once Covid cases passed 10%, a goverment understands they have
--		to take actions against the coronavirus pandemic.
--		So, we want to understand how fast different goverments succeeded to fully vaccinate 50% of the poputalion
;WITH CTE_indicators AS (
	SELECT 
		[date],
		[location],
		total_cases,
		[population],
		IIF(total_cases >= [population] * 0.1, 1, 0) AS total_cases_indicator,
		people_vaccinated,
		IIF(people_fully_vaccinated >= [population] * 0.5, 1, 0) AS people_fully_vaccinated_indicator
	FROM [dbo].[covid-data]
	WHERE
		LOWER(iso_code) NOT LIKE '%owid%'
		--AND [location] = 'United States'
	),
	CTE_Pandenic_crossed_10_pct_population AS (
	SELECT 
		[location],
		MIN([date]) AS Pandenic_crossed_10_pct_population
	FROM CTE_indicators
	WHERE
		total_cases_indicator = 1
	GROUP BY
		[location]
	),
	CTE_Fully_Vaccination_crossed_50_pct_population AS (
	SELECT 
		[location],
		MIN([date]) AS Fully_Vaccination_crossed_50_pct_population
	FROM CTE_indicators
	WHERE
		people_fully_vaccinated_indicator = 1
	GROUP BY
		[location]
	)
SELECT 
	T1.*,
	T2.Fully_Vaccination_crossed_50_pct_population,
	DATEDIFF(DAY, T1.Pandenic_crossed_10_pct_population, T2.Fully_Vaccination_crossed_50_pct_population) AS Day_Diff
FROM CTE_Pandenic_crossed_10_pct_population AS T1
	LEFT JOIN CTE_Fully_Vaccination_crossed_50_pct_population AS T2 ON T1.[location] = T2.[location]
ORDER BY
	DATEDIFF(DAY, T1.Pandenic_crossed_10_pct_population, T2.Fully_Vaccination_crossed_50_pct_population) ASC

--	What was the time difference between the first Covid case date and the first vaccination?
;WITH CTE_First_Covid_and_Vaccination_case AS (
	SELECT 
		[date],
		[location],
		total_cases,
		IIF(total_cases > 0, 1, 0) AS Covid_start_indicator,
		IIF(new_vaccinations > 0, 1, 0) AS Vaccination_start_indicator
	FROM [dbo].[covid-data]
	WHERE
		LOWER(iso_code) NOT LIKE '%owid%'
		--AND [location] = 'United States'
	),
	CTE_Covid_start_date AS (
	SELECT 
		[location],
		MIN([date]) AS Covid_start_date
	FROM CTE_First_Covid_and_Vaccination_case
	WHERE Covid_start_indicator = 1
	GROUP BY 
		[location]
	),
	CTE_Vaccination_start_date AS (
	SELECT 
		[location],
		MIN([date]) AS Vactination_start_date
	FROM CTE_First_Covid_and_Vaccination_case
	WHERE Vaccination_start_indicator = 1
	GROUP BY
		[location]
	)
SELECT 
	T1.*,
	T2.Vactination_start_date,
	DATEDIFF(DAY, T1.Covid_start_date, T2.Vactination_start_date) AS Covid_Vaccination_Day_Difference
FROM CTE_Covid_start_date AS T1
	LEFT JOIN CTE_Vaccination_start_date AS T2 ON T1.[location] = T2.[location] 
ORDER BY
	DATEDIFF(DAY, T1.Covid_start_date, T2.Vactination_start_date) ASC
;
