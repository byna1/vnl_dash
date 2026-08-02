SELECT 
    DISTINCT(t1.league_id) AS League_id,
    TRIM(REPLACE(t1.league_name,'Women','')) AS league_name,
    t1.country_code AS Country_id,
    CASE 
        WHEN t1.country_code = 'World' 
        THEN 'Internacional' 
        ELSE 'National' END AS league_type,
    CASE
        WHEN t1.league_name 
        LIKE '%Women%' 
        THEN 'Women' 
        ELSE 'Men' END AS league_naipe
FROM leagues t1
INNER JOIN matches t2
ON t1.league_id = t2.league_id
LEFT JOIN dim_countries
ON t1.country_code = t2.country_code