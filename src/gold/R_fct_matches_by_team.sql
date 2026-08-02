WITH 

tb_matches_melted

AS

(SELECT
    homeTeam_id AS team_id,
    'home' AS team_type,
    match_id,
    league_id,
    league_season,
    
    match_week,
    SUBSTR(match_date,1,16) as match_date,
    country_code AS league_country_code,
    current_home_team_score AS current_score,
    firstSet_home_team_score AS first_set_score,
    second_set_home_team_score AS second_set_score,
    third_set_home_team_score AS third_set_score,
    fourth_set_home_team_score AS fourth_set_score,
    fifth_set_home_team_score AS fifth_set_score,
    description AS match_status
    
FROM matches

UNION ALL 

SELECT
    awayTeam_id AS team_id,
    'away' AS team_type,
    match_id,
    league_id,
    league_season,
    match_week,
    SUBSTR(match_date,1,16) as match_date,
    country_code AS league_country_code,
    current_away_team_score AS current_score,
    firstSet_away_team_score AS first_set_score,
    second_set_away_team_score AS second_set_score,
    third_set_away_team_score AS third_set_score,
    fourth_set_away_team_score AS fourth_set_score,
    fifth_set_away_team_score AS fifth_set_score,
    description AS match_status
FROM matches),

tb_markers AS

(SELECT
   match_id,
   team_id,
   match_date,
   current_score,
   CASE WHEN match_week IS NULL THEN 'Preliminary' ELSE 'Finals' END champ_phase, 
   CASE
        WHEN ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY current_score DESC) = 1 THEN 'W' ELSE 'L' 
   END AS team_result, 
    ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY match_date DESC) AS match_order_general
FROM tb_matches_melted
WHERE match_status = 'Finished'
),

tb_order_preliminary
AS

(SELECT
    match_id,
    team_id, 
    champ_phase,
    match_date,
    ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY match_date DESC) AS preliminary_order
FROM tb_markers
WHERE champ_phase = 'Preliminary'),

tb_order_finals
AS

(SELECT
    match_id,
    team_id, 
    champ_phase,
    match_date,
    ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY match_date DESC) AS final_order
FROM tb_markers
WHERE champ_phase = 'Finals'),

tb_join 

AS
(SELECT 
    t1.team_id AS Team_id,
    CONCAT(t1.league_id, '_', t1.league_season) AS league_season_id,
    t1.team_type,
    t1.match_id,
    t1.league_id,
    t1.league_season,
    t1.match_week,
    t1.match_date,
    t1.league_country_code,
    t1.current_score,
    t1.first_set_score,
    t1.second_set_score,
    t1.third_set_score,
    t1.fourth_set_score,
    t1.fifth_set_score,
    t1.match_status,
    t2.team_result,
    t2.champ_phase,
    t2.match_order_general,
    t3.preliminary_order,
    t4.final_order
FROM tb_matches_melted AS t1
LEFT JOIN tb_markers  AS t2
ON t1.match_id = t2.match_id
AND t1.team_id = t2.team_id
LEFT JOIN tb_order_preliminary t3 
ON t1.match_id = t3.match_id
AND t1.team_id = t3.team_id
LEFT JOIN tb_order_finals t4
ON t1.match_id = t4.match_id
AND t1.team_id = t4.team_id
ORDER BY t1.match_date DESC, t1.match_id
)

SELECT * 
FROM tb_join 
ORDER BY match_id, team_id
