SELECT
    league_id,
    'away' AS team_type,
    team_id,
    season AS league_season,
    total_games_played,
    total_games_wins,
    total_games_loses,
    total_points_scored,
    total_points_received,
    away_games_played,
    away_games_wins,
    away_games_loses,
    away_points_scored,
    away_points_received
FROM team_stats


UNION ALL

SELECT
    league_id,
    'home' AS team_type,
    team_id,
    season AS league_season,
    total_games_played,
    total_games_wins,
    total_games_loses,
    total_points_scored	,
    total_points_received,
    home_games_played,
    home_games_wins,
    home_games_loses,
    home_points_scored,
    home_points_received
FROM team_stats
ORDER BY league_id,team_id, season DESC