WITH 

tb_union

AS

(SELECT 
    league_season_id, 
    team_id 
FROM fct_intern_matches_melted_by_team

UNION

SELECT 
    league_season_id, 
    team_id 
FROM fct_national_matches_melted_by_team)

SELECT 
    DISTINCT league_season_id,
    team_id
FROM tb_union