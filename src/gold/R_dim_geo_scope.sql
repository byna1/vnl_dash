WITH 

tb_geo

AS

(SELECT
    country_code AS Geo_scope_id,
    country_name AS geo_scope_name,
    CASE 
        
        WHEN country_name = 'World' THEN 'International' ELSE 'National' 
    
    END geo_aggreg,
     CASE 
        WHEN country_code = 'World' THEN NULL ELSE country_code 
    END AS country_id
FROM countries
WHERE country_name NOT IN
('Europe', 'South America', 'North America', 'Africa', 'Oceania'))

SELECT *
FROM tb_geo
