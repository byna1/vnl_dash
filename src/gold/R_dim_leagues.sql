WITH league_country AS (
    SELECT
        league_id,
        MAX(country_code) AS real_country_code
    FROM matches
    WHERE country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')
    GROUP BY league_id
),

tb_leagues AS (
    SELECT DISTINCT
        t1.league_id AS league_id,
        TRIM(REPLACE(t1.league_name, 'Women', '')) AS league_name,
        COALESCE(t2.real_country_code, 'World') AS country_id,
        CASE WHEN t1.league_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS league_naipe
    FROM leagues t1
    LEFT JOIN league_country t2
        ON t1.league_id = t2.league_id
),

tb_join AS (
    SELECT
        t1.league_id AS League_id,
        t1.league_name,
        CASE WHEN t1.country_id = 'World' THEN 'International' ELSE 'National' END AS league_type,
        t1.league_naipe,
        t1.country_id
    FROM tb_leagues t1
)

SELECT *
FROM tb_join
WHERE league_type = 'National'
OR league_name IN ('World Championship', 'Olympic Games', 'Nations League')
ORDER BY league_id