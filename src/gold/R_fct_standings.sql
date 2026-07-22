SELECT
    team_id,
    league_id,
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