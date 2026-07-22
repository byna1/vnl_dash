SELECT
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
FROM matches
ORDER BY league_season DESC, match_id