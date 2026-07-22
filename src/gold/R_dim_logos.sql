WITH 

tb_team AS (
    SELECT
        team_id,
        team_logo,
        TRIM(REPLACE(REPLACE(team_name,'Women',''),'Men','')) AS team_name
    FROM teams
)


SELECT
    t.team_id,
    t.team_name,
    l.country_code AS league_cc,
    CASE
        WHEN l.country_code = 'World' THEN c.country_logo ELSE t.team_logo                                    
    END AS logo_final
FROM tb_team AS t
LEFT JOIN standings AS s 
ON s.team_id = t.team_id        
LEFT JOIN leagues AS l 
ON l.league_id = s.league_id    
LEFT JOIN countries AS c 
ON c.country_name = t.team_name