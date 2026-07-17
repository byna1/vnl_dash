SELECT 
    match_id,
    'away' AS team_type,
    [type] AS statistics_type,
    CASE 
        WHEN [set] = '1ST' THEN 1
        WHEN [set] = '2ND' THEN 2
        WHEN [set] = '3RD' THEN 3
        WHEN [set] = '4TH' THEN 4
        WHEN [set] = '5TH' THEN 5
        ELSE NULL
    END AS set_number,
    category,
    away_team_match_score AS team_stats
FROM matches_statistics 
WHERE [set] = '1ST' 
OR [set] =  '2ND'
OR [set] =  '3RD'
OR [set] =  '4TH' 
OR [set] =  '5TH'

UNION ALL

SELECT 
    match_id,
    'home' AS team_type,
    [type] AS statistics_type,
    CASE 
        WHEN [set] = '1ST' THEN 1
        WHEN [set] = '2ND' THEN 2
        WHEN [set] = '3RD' THEN 3
        WHEN [set] = '4TH' THEN 4
        WHEN [set] = '5TH' THEN 5
        ELSE NULL
    END AS set_number,
    category,
    away_team_match_score team_stats
FROM matches_statistics
WHERE [set] = '1ST' 
OR [set] =  '2ND'
OR [set] =  '3RD'
OR [set] =  '4TH' 
OR [set] =  '5TH'
ORDER BY match_id