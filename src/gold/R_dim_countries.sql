WITH

tb_naipe

AS

(SELECT 
    country_code AS Country_id,
    country_name,
    country_logo,
    'Women' AS country_naipe
FROM countries
WHERE country_name NOT IN
('World', 'Europe', 'South America', 'North America', 'Africa', 'Oceania')

UNION ALL 

SELECT 
    country_code AS Country_id,
    country_name,
    country_logo,
    'Men' AS country_naipe
FROM countries
WHERE country_name NOT IN
('World', 'Europe', 'South America', 'North America', 'Africa', 'Oceania')
ORDER BY Country_id)

SELECT
    CONCAT(country_id,'_',country_naipe) AS country_naipe_id,
    Country_id,
    country_name,
    country_logo
FROM tb_naipe