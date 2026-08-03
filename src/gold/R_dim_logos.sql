WITH tb_team AS (
    SELECT DISTINCT
        team_id,
        team_logo,
        TRIM(REPLACE(REPLACE(team_name, 'Women', ''), 'Men', '')) AS team_name
    FROM teams
)

SELECT
    t1.team_id AS Team_id,
    COALESCE(t2.country_logo, t1.team_logo) AS logo_final
FROM tb_team AS t1
LEFT JOIN countries AS t2
    ON t2.country_name = t1.team_name