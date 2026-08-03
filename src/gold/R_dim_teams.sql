WITH melted AS (
    SELECT homeTeam_id AS team_id, country_code AS liga_code FROM matches
    UNION ALL
    SELECT awayTeam_id AS team_id, country_code AS liga_code FROM matches
),

team_country AS (
    SELECT
        t1.team_id,
        MAX(t2.country_code) AS country_code
    FROM melted t1
    LEFT JOIN countries t2
        ON t1.liga_code = t2.country_code
        AND t2.country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')
    GROUP BY t1.team_id
),

tb_join

AS

(SELECT
    t1.team_id AS Team_id,
    TRIM(REPLACE(t1.team_name, 'Women', '')) AS team_name,
    CASE WHEN t1.team_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS team_naipe,
    CASE WHEN t3.country_code IS NOT NULL THEN 'National Team' ELSE 'Club' END AS team_type,
    COALESCE(t2.country_code, t3.country_code) AS country_id
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
-- Clubs from other classes than adults were removed also, clubs where the leagues do not have any matches on the bank were removed.
WHERE country_id IS NOT NULL
-- Puerto Rico was removed manually: it's a city club with no registered national league on the base,
-- and it also can't be treated as a US national team.
AND team_id <> '1904471')

SELECT *
FROM tb_removed_scope