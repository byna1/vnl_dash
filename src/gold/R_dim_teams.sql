WITH melted AS (
    SELECT homeTeam_id AS team_id,
    league_id,
    country_code AS liga_code 
    FROM matches
    UNION ALL
    SELECT awayTeam_id AS team_id,
    league_id, 
    country_code AS liga_code 
    FROM matches
),

team_country AS (
    SELECT
        t3.league_name,
        t1.team_id,
        MAX(t2.country_code) AS country_code
    FROM melted t1
    LEFT JOIN countries t2
        ON t1.liga_code = t2.country_code
        AND t2.country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')
    LEFT JOIN leagues t3 
    ON t1.league_id = t3.league_id
    GROUP BY t1.team_id
),

tb_join

AS

(SELECT
    t1.team_id AS Team_id,
    TRIM(REPLACE(t1.team_name, 'Women', '')) AS team_name,
        CASE 
            WHEN t2.league_name LIKE '%Women%' THEN 'Women' 
            WHEN t2.league_name LIKE '%Femenina%' THEN 'Women'
            WHEN t2.league_name LIKE '%Female%' THEN 'Women'
            WHEN t2.league_name LIKE '%Feminina%' THEN 'Women' 
        ELSE 'Men' END AS team_naipe,
    CASE WHEN t3.country_code IS NOT NULL THEN 'National Team' ELSE 'Club' END AS team_type,
    COALESCE(t3.country_code, t2.country_code) AS country_id
FROM teams t1
LEFT JOIN team_country t2
    ON t1.team_id = t2.team_id
LEFT JOIN countries t3
    ON TRIM(REPLACE(t1.team_name, 'Women', '')) = t3.country_name
    AND t3.country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')),

tb_removed_scope

AS

(
SELECT * 
FROM tb_join
-- teams where no information about where the league 
-- was located or different than adult leagues 
-- resulted as null and were removed
WHERE country_id IS NOT NULL)

SELECT 
    CONCAT(country_id,'_',team_naipe) AS country_naipe_id,
    t1.*
FROM tb_removed_scope t1
ORDER BY country_id