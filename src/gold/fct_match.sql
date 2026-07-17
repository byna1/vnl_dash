SELECT tournament_id,
    season_id,
    match_id,
    SUBSTR(times_specific_start_time, 1, 10) AS start_time,
    'home' AS team_type,
    home_team_id AS team_id,
    home_team_match_score AS match_score,
    home_team_score_set_1 AS set_1,
    home_team_score_set_2 AS set_2,
    home_team_score_set_3 AS set_3,
    home_team_score_set_4 AS set_4,
    home_team_score_set_5 AS set_5,
    (CASE WHEN home_team_score_set_1 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_2 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_3 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_4 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_5 IS NOT NULL THEN 1 ELSE 0 END) AS game_total_sets

FROM match_info

UNION ALL

SELECT tournament_id,
    season_id,
    match_id,
    SUBSTR(times_specific_start_time, 1, 10) AS start_time,
    'away' AS team_type,
    away_team_id AS team_id,
    away_team_match_score AS match_score,
    away_team_score_set_1 AS set_1,
    away_team_score_set_2 AS set_2,
    away_team_score_set_3 AS set_3,
    away_team_score_set_4 AS set_4,
    away_team_score_set_5 AS set_5,
    (CASE WHEN home_team_score_set_1 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_2 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_3 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_4 IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN home_team_score_set_5 IS NOT NULL THEN 1 ELSE 0 END) AS game_total_sets
FROM match_info
ORDER BY match_id