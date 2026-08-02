WITH season_agg AS (
    SELECT
        CONCAT(t1.league_id, '_', t1.league_season) AS league_season_id,
        t1.league_id,
        t1.league_season,
        MIN(t2.match_date) AS season_start_date,
        MAX(t2.match_date) AS last_match_date,
        MAX(
            CASE 
                WHEN t2.match_week LIKE '%Final%' 
                 AND t2.match_week NOT LIKE '%Semi%' 
                 AND t2.match_week NOT LIKE '%Quarter%'
                THEN 1 ELSE 0 
            END
        ) AS has_final
    FROM leagues AS t1
    INNER JOIN matches AS t2
        ON t1.league_id = t2.league_id
        AND t1.league_season = t2.league_season
    GROUP BY t1.league_id, t2.league_season
),

with_max_season AS (
    SELECT
        *,
        MAX(league_season) OVER (PARTITION BY league_id) AS max_season,
        MAX(league_season) OVER () AS global_max_season
    FROM season_agg
),

tb_gn
AS
(SELECT
    league_season_id AS League_season_id,
    league_id,
    league_season,
    season_start_date,
    CASE
        WHEN has_final = 1 THEN last_match_date
        WHEN league_season < max_season THEN last_match_date
        WHEN league_season < global_max_season THEN last_match_date
        ELSE NULL
    END AS season_end_date
FROM with_max_season
ORDER BY league_id, league_season)

SELECT *,
    CASE WHEN season_end_date IS NOT NULL THEN 'Finished' ELSE 'Not Finished' END season_status
FROM tb_gn