WITH team_games_stats

AS

(SELECT
    t1.league_id,
    t1.team_id,
    t1.season,
    t1.total_games_played,
    t1.total_games_wins,
    t1.total_games_loses,
    t1.total_points_scored,
    t1.total_points_received,
    t1.total_points_scored - total_points_received AS delta_points
FROM team_stats t1
INNER JOIN leagues t2
ON t1.league_id = t2.league_id),

matches_melted AS

(SELECT
    match_id,
    'home' AS team_type,
    league_season,
    match_week,
    homeTeam_id AS team_id,
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
    match_id,
    'away' AS team_type,
    league_season,
    match_week,
    awayTeam_id AS team_id,
    current_away_team_score AS current_score,
    firstSet_away_team_score AS first_set_score,
    second_set_away_team_score AS second_set_score,
    third_set_away_team_score AS third_set_score,
    fourth_set_away_team_score AS fourth_set_score,
    fifth_set_away_team_score AS fifth_set_score,
    description AS match_status
FROM matches),

tb_count_match_week

AS

(SELECT 
    team_id,
    league_season,
    COUNT(CASE WHEN fifth_set_score IS NOT NULL THEN 1 END) AS total_games_5_sets,
    COUNT(CASE WHEN match_week = 'Final' THEN 1 END) AS total_finals,
    COUNT(CASE WHEN match_week = 'Semi-finals' THEN 1 END) AS total_semi_finals,
    COUNT(CASE WHEN match_week = '3rd place' THEN 1 END) AS total_3rd_place_dispute,
    COUNT(CASE WHEN match_week = 'Quarter-finals' THEN 1 END) AS total_4r_finals_appearances
FROM matches_melted
GROUP BY team_id, league_season),

tb_matches_3_x_0

AS

(SELECT
    match_id,
    team_id,
    league_season,
    first_set_score,
    second_set_score,
    third_set_score,
    fourth_set_score,
    fifth_set_score,
    match_status,
    ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY current_score DESC) AS winners_order
FROM matches_melted
),

total_3x0_wins

AS

(SELECT 
    team_id,
    league_season,
    SUM(CASE 
        WHEN winners_order = 1 AND fourth_set_score IS NULL AND match_status = 'Finished' THEN 1 ELSE 0 
        END) AS n_3_x_0_wins
FROM tb_matches_3_x_0
GROUP BY team_id,league_season),


sets_won

AS

(SELECT
    match_id,
    team_id,
    league_season,
    CASE WHEN winners_order=1 THEN 'W' ELSE 'L' END as team_result,
    CASE WHEN first_set_score IS NOT NULL AND ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY first_set_score DESC)=1 THEN 1 ELSE 0 END AS set_1_win,
    CASE WHEN second_set_score IS NOT NULL AND ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY second_set_score DESC)=1 THEN 1 ELSE 0 END AS second_set_win,
    CASE WHEN third_set_score IS NOT NULL AND ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY third_set_score DESC)=1 THEN 1 ELSE 0 END AS third_set_win,
    CASE WHEN fourth_set_score IS NOT NULL AND ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY fourth_set_score DESC)=1 THEN 1 ELSE 0 END AS fourth_set_win,
    CASE WHEN fifth_set_score IS NOT NULL AND ROW_NUMBER() OVER (PARTITION BY match_id ORDER BY fifth_set_score DESC)=1 THEN 1 ELSE 0 END AS fifth_set_win
FROM tb_matches_3_x_0
),

tb_sets_won

AS

(SELECT 
    team_id,
    league_season,
    SUM(set_1_win) AS set_1_win,
    SUM(second_set_win) AS second_set_win,
    SUM(third_set_win) AS third_set_win,
    SUM(fourth_set_win) AS fourth_set_win,
    SUM(fifth_set_win) AS fifth_set_win
FROM sets_won
GROUP BY team_id, league_season
),

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

tb_tight_flag AS (
    SELECT *,
        (CASE WHEN delta_1 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_2 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_3 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_4 <= 3 THEN 1 ELSE 0 END)
      + (CASE WHEN delta_5 <= 3 THEN 1 ELSE 0 END) AS n_tight_sets
    FROM tight_matches
),

tb_team_tight_games

AS

(SELECT
    t2.team_id,
    t2.league_season,
    COUNT(*) n_tight_games_won
FROM tb_tight_flag t1
INNER JOIN sets_won t2
ON t1.match_id = t2.match_id
WHERE t2.team_result = 'W'
AND ((t1.delta_4 IS NULL AND t1.n_tight_sets >= 3)
  OR (t1.delta_4 IS NOT NULL AND t1.n_tight_sets >= 3))
GROUP BY t2.team_id, t2.league_season),

tb_join

AS

(SELECT 
    t1.team_id,
    t1.season AS league_season,
    t1.total_games_played AS season_games_played,
    t1.total_games_wins AS season_games_won,
    t1.total_games_loses AS season_games_lost,
    t1.total_points_scored AS sets_won,
    t1.total_points_received AS sets_lost,
    t1.delta_points AS sets_delta,
    CASE WHEN t2.total_finals IS NULL THEN 0 ELSE total_finals END total_finals,
    CASE WHEN t2.total_semi_finals IS NULL THEN 0 ELSE total_semi_finals END total_semi_finals,
    CASE WHEN t2.total_3rd_place_dispute IS NULL THEN 0 ELSE total_3rd_place_dispute END total_3rd_place_dispute,
    CASE WHEN t2.total_4r_finals_appearances IS NULL THEN 0 ELSE total_4r_finals_appearances END total_4r_finals_appearances,
    CASE WHEN t3.n_3_x_0_wins IS NULL THEN 0 ELSE t3.n_3_x_0_wins END AS n_3_x_0_wins,
    t2.total_games_5_sets,
    CASE WHEN t4.set_1_win IS NULL THEN 0 ELSE t4.set_1_win END AS set_1_win,
    CASE WHEN t4.second_set_win IS NULL THEN 0 ELSE t4.second_set_win END AS set_2_win,
    CASE WHEN t4.third_set_win IS NULL THEN 0 ELSE t4.third_set_win END AS set_3_win,
    CASE WHEN t4.fourth_set_win IS NULL THEN 0 ELSE t4.fourth_set_win END AS set_4_win,
    CASE WHEN t4.fifth_set_win IS NULL THEN 0 ELSE t4.fifth_set_win END AS set_5_win,
    CASE WHEN t5.n_tight_games_won IS NULL THEN 0 ELSE t5.n_tight_games_won END AS n_tight_games_won
FROM team_games_stats AS t1
LEFT JOIN tb_count_match_week AS t2
ON t1.team_id = t2.team_id
AND t1.season = t2.league_season
LEFT JOIN total_3x0_wins AS t3
ON t1.team_id = t3.team_id
AND t1.season = t3.league_season
LEFT JOIN tb_sets_won AS t4
ON t1.team_id = t4.team_id
AND t1.season = t4.league_season
LEFT JOIN tb_team_tight_games AS t5
ON t1.team_id = t5.team_id
AND t1.season = t5.league_season
GROUP BY t1.team_id,t1.season)

SELECT * 
FROM tb_join
WHERE team_id = 1886600