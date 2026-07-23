WITH

tb_matches_treated

AS

(SELECT
    match_id,
    CAST(MAX(CASE WHEN team_type = 'home' THEN current_score END) AS INT) awayTeam_score,
    CAST(MAX(CASE WHEN team_type = 'away' THEN current_score END) AS INT) homeTeam_score,
    MAX(CASE WHEN team_type = 'away' THEN t2.team_id END) awayTeam_id,
    MAX(CASE WHEN team_type = 'away' THEN t2.team_id END) homeTeam_id,
    MAX(CASE WHEN team_type = 'home' THEN team_name END) homeTeam_name,
    MAX(CASE WHEN team_type = 'away' THEN team_name END) awayTeam_name
FROM fct_matches_by_team t1
LEFT JOIN dim_teams t2
ON t1.team_id = t2.team_id
GROUP BY match_id)

SELECT * 
FROM tb_matches_treated
