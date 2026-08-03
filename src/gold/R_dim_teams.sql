WITH tb_teams AS (
    SELECT
        team_id,
        TRIM(REPLACE(team_name, 'Women', '')) AS team_name,
        CASE WHEN team_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS team_naipe
    FROM teams
),

tb_team_country AS (
    SELECT homeTeam_id AS team_id, country_code AS country_id FROM matches
    UNION
    SELECT awayTeam_id AS team_id, country_code AS country_id FROM matches
)

SELECT
    t1.team_id AS Team_id,
    t2.country_id,
    t1.team_name,
    t1.team_naipe,
    CASE 
        WHEN t2.country_id = 'World' THEN 'International' ELSE 'National'
    END AS team_type
FROM tb_teams AS t1
LEFT JOIN tb_team_country AS t2
    ON t1.team_id = t2.team_id