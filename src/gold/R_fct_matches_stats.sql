WITH tb_match

AS

(SELECT 
    match_id,
    league_id,
    match_week,
    SUBSTR(match_date,1,16) as match_date,
    homeTeam_id,
    awayTeam_id,
    TRIM(league_season) AS league_season,
    current_home_team_score,
    current_away_team_score,
	firstSet_home_team_score,
    firstSet_away_team_score,
    second_set_home_team_score,
    second_set_away_team_score,
   	third_set_home_team_score,
    third_set_away_team_score,
    fourth_set_home_team_score,
    fourth_set_away_team_score,
    fifth_set_home_team_score,
    fifth_set_away_team_score,
    CASE WHEN current_home_team_score > current_away_team_score THEN homeTeam_id ELSE awayTeam_id END match_winner,
    description AS match_status

FROM matches),

tight_matches AS (
    SELECT
        match_id,
        league_season,
        ABS(firstSet_home_team_score  - firstSet_away_team_score)  AS delta_1,
        ABS(second_set_home_team_score - second_set_away_team_score) AS delta_2,
        ABS(third_set_home_team_score  - third_set_away_team_score)  AS delta_3,
        ABS(fourth_set_home_team_score - fourth_set_away_team_score) AS delta_4,
        ABS(fifth_set_home_team_score  - fifth_set_away_team_score)  AS delta_5
    FROM matches
),

tight_flag AS 

(
    SELECT *,
        (CASE WHEN delta_1 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_2 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_3 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_4 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_5 <= 3 THEN 1 ELSE 0 END) AS n_tight_sets
    FROM tight_matches
),

tigh_match_flag
AS
(SELECT *
FROM tight_flag
WHERE delta_4 IS NOT NULL
  AND n_tight_sets >= 3
ORDER BY n_tight_sets DESC, league_season),

team_name_melted

AS

(SELECT
    homeTeam_id AS team_id,
    'home' AS team_type,
    match_id
FROM matches

UNION ALL

SELECT
    awayTeam_id AS team_id,
    'away' AS team_type,
    match_id
FROM matches),

tb_team_names

AS

(SELECT
    match_id,
    MAX(CASE WHEN team_type = 'home' THEN team_name END) homeTeam_name,
    MAX(CASE WHEN team_type = 'away' THEN team_name END) awayTeam_name
FROM team_name_melted AS t1
LEFT JOIN teams AS t2
ON t1.team_id = t2.team_id
GROUP BY t1.match_id),

tb_names_treated

AS

(SELECT
    match_id,
    TRIM(REPLACE(REPLACE(homeTeam_name,'Women',''),'Men','')) homeTeam_name,
    TRIM(REPLACE(REPLACE(awayTeam_name,'Women',''),'Men','')) awayTeam_name
FROM tb_team_names),


tb_join

AS

(SELECT 
    t1.match_id AS Match_id,
    CONCAT(t1.league_id, '_', t1.league_season) AS league_season_id,
    t1.league_id,
    t1.league_season,
    t1.match_week,
    t1.match_date,
    t1.homeTeam_id,
    t1.awayTeam_id,
    t3.homeTeam_name,
    t3.awayTeam_name,
    t1.match_winner,
    t1.match_status,
    t1.current_home_team_score,
    t1.current_away_team_score,
	t1.firstSet_home_team_score,
    t1.firstSet_away_team_score,
    t1.second_set_home_team_score,
    t1.second_set_away_team_score,
   	t1.third_set_home_team_score,
    t1.third_set_away_team_score,
    t1.fourth_set_home_team_score,
    t1.fourth_set_away_team_score,
    t1.fifth_set_home_team_score,
    t1.fifth_set_away_team_score,
    CASE WHEN t2.n_tight_sets IS NULL THEN 0 ELSE t2.n_tight_sets END AS n_tight_sets
FROM tb_match AS t1
LEFT JOIN tigh_match_flag AS t2
ON t1.match_id = t2.match_id
AND t1.league_season = t2.league_season
LEFT JOIN tb_names_treated AS t3
ON t1.match_id = t3.match_id)

SELECT * 
FROM tb_join




