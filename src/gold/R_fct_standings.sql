SELECT
    CONCAT(league_id, '_', league_season) AS League_season_id,
    league_id AS league_id,
    team_id,
    league_season,
    wins,
    loses,
    points,
    standing_position,
    games_played,
    scored_points,
    received_points
FROM standings
ORDER BY league_season DESC