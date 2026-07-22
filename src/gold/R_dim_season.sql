SELECT
    t1.league_id,
    t1.league_season,
    MIN(t2.match_date) AS season_start_date,
    CASE WHEN MAX(CASE WHEN t2.match_week = 'Final' THEN 1 ELSE 0 END) = 1
         THEN MAX(t2.match_date)
         ELSE NULL END AS season_end_date
FROM leagues AS t1
LEFT JOIN matches AS t2
ON t1.league_id = t2.league_id
AND t1.league_season = t2.league_season
GROUP BY t1.league_id, t1.league_season