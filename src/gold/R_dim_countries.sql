SELECT 
    country_code AS Country_id,
    country_name,
    country_logo
FROM countries
WHERE country_name NOT IN
('World', 'Europe', 'South America', 'North America', 'Africa', 'Oceania')