SELECT 
    t1.season_name,
    COUNT (DISTINCT CASE
                WHEN t2.match_id IS NOT NULL THEN t2.match_id ELSE NULL
         END ) AS matches_statistics_available,
    COUNT (DISTINCT t1.match_id) AS total_matches
FROM season_tournment AS t1
LEFT JOIN statistics AS t2
ON t1.match_id = t2.match_id
GROUP BY t1.season_name

