WITH 

tb_teams

AS 


(
    SELECT
        team_id,
        team_logo,
        TRIM(REPLACE(team_name,'Women','')) AS team_name,
        CASE WHEN team_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS team_naipe
    FROM teams
)


SELECT
    team_id,
    COALESCE(
        NULLIF(team_logo,''),
        MAX(NULLIF(team_logo,'')) OVER (PARTITION BY team_name)
    ) AS team_logo,
    team_name,
    team_naipe
FROM tb_teams