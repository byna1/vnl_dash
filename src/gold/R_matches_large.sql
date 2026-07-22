SELECT
    league_id,
    league_season,
    match_id,
    match_week,
    SUBSTR(match_date,1,16) as match_date,
    country_code AS league_country_code,
    homeTeam_id,
    awayTeam_id,
    current_home_team_score AS home_current_sets_won,
    current_away_team_score AS away_current_sets_won,
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
    description AS match_status
FROM matches
ORDER BY league_season DESC, match_id