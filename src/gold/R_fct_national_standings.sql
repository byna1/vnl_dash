WITH
-- deliberate cut: a league_season with a single match is a one-off final, not a
-- rankable league. we drop it here on purpose so it never enters the pipeline
tb_single_match_seasons AS (
    SELECT
        CONCAT(league_id, '_', TRIM(league_season)) AS league_season_id
    FROM matches
    WHERE description = 'Finished'
      AND country_name NOT IN
          ('World','Europe','South America','North America','Africa','Oceania')
    GROUP BY league_id, TRIM(league_season)
    HAVING COUNT(*) = 1
),

tb_scope AS (
    SELECT
        match_id,
        match_date,
        league_id,
        league_name,
        country_code,
        TRIM(league_season) AS league_season,
        CONCAT(league_id, '_', TRIM(league_season)) AS league_season_id,
        homeTeam_id,
        homeTeam_name,
        awayTeam_id,
        awayTeam_name,
        match_week,
        current_home_team_score AS home_score,
        current_away_team_score AS away_score,
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
        CASE WHEN fifth_set_home_team_score IS NOT NULL THEN 1 ELSE 0 END AS went_5
    FROM matches
    WHERE description = 'Finished'
      AND country_name NOT IN
          ('World','Europe','South America','North America','Africa','Oceania')
      -- keeping only real countries: the domestic club leagues, not the international scope
      AND CONCAT(league_id, '_', TRIM(league_season)) NOT IN (SELECT league_season_id 
                                                                FROM tb_single_match_seasons)
),

tb_sets AS (
    SELECT t1.*,
        -- sets won by home team (direct home-vs-away so unplayed NULL sets never count)
        (CASE WHEN firstSet_home_team_score  > firstSet_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_home_team_score > second_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_home_team_score  > third_set_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_home_team_score > fourth_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_home_team_score  > fifth_set_away_team_score  THEN 1 ELSE 0 END) AS home_sets,
        -- sets won by away team
        (CASE WHEN firstSet_away_team_score  > firstSet_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_away_team_score > second_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_away_team_score  > third_set_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_away_team_score > fourth_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_away_team_score  > fifth_set_home_team_score  THEN 1 ELSE 0 END) AS away_sets
    FROM tb_scope t1
),

-- melting to (league_season, team_id) granularity
tb_melted AS (
    SELECT
        match_id,
        league_id,
        league_name,
        match_week,
        country_code,
        league_season,
        league_season_id,
        homeTeam_id AS team_id,
        CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS has_won,
        CASE
            WHEN home_score > away_score AND went_5 = 0 THEN 3
            WHEN home_score > away_score AND went_5 = 1 THEN 2
            WHEN home_score < away_score AND went_5 = 1 THEN 1
        ELSE 0
        END AS match_points,   -- FIVB 3-2-1-0
        home_sets AS sets_won,
        away_sets AS sets_lost,
        CASE
            WHEN match_week LIKE '%Final%' OR match_week LIKE '%3rd place%'
              OR match_week LIKE '%Quarter%' OR match_week LIKE '%Semi%'
            THEN 'Finals'
            ELSE 'Preliminary'
        END AS champ_phase
        -- match_week that is a plain round number, or NULL, falls into the ELSE = regular season
    FROM tb_sets

    UNION ALL

    SELECT
        match_id,
        league_id,
        league_name,
        match_week,
        country_code,
        league_season,
        league_season_id,
        awayTeam_id AS team_id,
        CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS has_won,
        CASE
            WHEN away_score > home_score AND went_5 = 0 THEN 3
            WHEN away_score > home_score AND went_5 = 1 THEN 2
            WHEN away_score < home_score AND went_5 = 1 THEN 1
            ELSE 0
        END AS match_points,
        away_sets AS sets_won,
        home_sets AS sets_lost,
        CASE
            WHEN match_week LIKE '%Final%' OR match_week LIKE '%3rd place%'
              OR match_week LIKE '%Quarter%' OR match_week LIKE '%Semi%'
            THEN 'Finals'
            ELSE 'Preliminary'
        END AS champ_phase
    FROM tb_sets
),

-- regular-season aggregate per team-season
tb_prelim AS (
    SELECT
        team_id,
        league_id,
        league_name,
        country_code,
        league_season,
        league_season_id,
        SUM(has_won) AS games_won,
        SUM(1 - has_won) AS games_lost,
        SUM(match_points) AS match_points,
        SUM(sets_won) AS sets_won,
        SUM(sets_lost) AS sets_lost,
        CAST(SUM(sets_won) AS FLOAT) / NULLIF(SUM(sets_lost), 0) AS set_ratio
    FROM tb_melted
    WHERE champ_phase = 'Preliminary'
    GROUP BY team_id, league_id, league_name, country_code, league_season, league_season_id
),

-- regular-season position (FIVB order) + how many teams the league had that season
tb_league_preliminary_ranking AS (
    SELECT t1.*,
        ROW_NUMBER() OVER (
            PARTITION BY t1.league_season_id
            ORDER BY t1.games_won DESC, t1.match_points DESC, t1.set_ratio DESC
        ) AS prelim_position,
        COUNT(*) OVER (PARTITION BY t1.league_season_id) AS total_teams_this_season
    FROM tb_prelim t1
),

-- finals/bronze aggregated per team-season. multiple finals (e.g. Liga 1 two-legged
-- ties) get counted as a series here: wins, match_points and set balance summed across
-- all final games, then ranked as a series in the next CTEs
tb_finals AS (
    SELECT
        team_id,
        league_season_id,
        -- final series: everything that is a Final but not Semi/Quarter
        SUM(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                  AND match_week NOT LIKE '%Quarter%' THEN 1 ELSE 0 END) AS final_games,
        SUM(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                  AND match_week NOT LIKE '%Quarter%' AND has_won = 1 THEN 1 ELSE 0 END) AS final_wins,
        SUM(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                  AND match_week NOT LIKE '%Quarter%' THEN match_points ELSE 0 END) AS final_match_points,
        -- set balance instead of ratio: no division, no NULL flipping a 0-loss sweep to last
        SUM(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                  AND match_week NOT LIKE '%Quarter%' THEN sets_won - sets_lost ELSE 0 END) AS final_set_balance,
        -- 3rd place series
        SUM(CASE WHEN match_week LIKE '%3rd place%' THEN 1 ELSE 0 END) AS bronze_games,
        SUM(CASE WHEN match_week LIKE '%3rd place%' AND has_won = 1 THEN 1 ELSE 0 END) AS bronze_wins,
        SUM(CASE WHEN match_week LIKE '%3rd place%' THEN match_points ELSE 0 END) AS bronze_match_points,
        SUM(CASE WHEN match_week LIKE '%3rd place%' THEN sets_won - sets_lost ELSE 0 END) AS bronze_set_balance,
        MAX(CASE WHEN match_week LIKE '%Quarter%' THEN 1 ELSE 0 END) AS played_qf
    FROM tb_melted
    WHERE champ_phase = 'Finals'
    GROUP BY team_id, league_season_id
),

-- prelim_position pulled in here so the series tiebreak can fall back on it (FIVB level
-- 4 collapsed to preliminary standing) as the final deterministic key
tb_finals_and_prelim AS (
    SELECT t1.*,
        t2.prelim_position
    FROM tb_finals t1
    LEFT JOIN tb_league_preliminary_ranking t2
        ON t1.team_id = t2.team_id
        AND t1.league_season_id = t2.league_season_id
),

-- final-series standing. window isolated in its own CTE. tiebreak hierarchy:
-- wins -> match_points -> set_balance -> prelim_position
tb_final_series_rank AS (
    SELECT team_id, league_season_id,
        ROW_NUMBER() OVER (
            PARTITION BY league_season_id
            ORDER BY final_wins DESC,
                     final_match_points DESC,
                     final_set_balance DESC,
                     prelim_position ASC
        ) AS final_pos
    FROM tb_finals_and_prelim
    WHERE final_games > 0
),

-- 3rd place series standing. same hierarchy, own isolated window
tb_bronze_series_rank AS (
    SELECT team_id, league_season_id,
        ROW_NUMBER() OVER (
            PARTITION BY league_season_id
            ORDER BY bronze_wins DESC,
                     bronze_match_points DESC,
                     bronze_set_balance DESC,
                     prelim_position ASC
        ) AS bronze_pos
    FROM tb_finals_and_prelim
    WHERE bronze_games > 0
),

tb_finalist_bucket AS (
    SELECT
        t1.team_id,
        t1.league_season_id,
        CASE
            WHEN t2.final_pos  = 1 THEN 1   -- won the final series
            WHEN t2.final_pos  = 2 THEN 2   -- lost the final series
            WHEN t3.bronze_pos = 1 THEN 3
            WHEN t3.bronze_pos = 2 THEN 4
            WHEN t1.played_qf  = 1 THEN 5
            ELSE NULL
        END AS finalist_bucket
    FROM tb_finals_and_prelim t1
    LEFT JOIN tb_final_series_rank t2
        ON t1.team_id = t2.team_id AND t1.league_season_id = t2.league_season_id
    LEFT JOIN tb_bronze_series_rank t3
        ON t1.team_id = t3.team_id AND t1.league_season_id = t3.league_season_id
),

tb_join AS (
    SELECT
        t1.league_season_id,
        t1.league_id,
        t1.country_code,
        t1.team_id,
        t1.league_season,
        t1.prelim_position,
        t1.total_teams_this_season,
        t1.games_won,
        t1.games_lost,
        t1.match_points,
        t1.sets_won,
        t1.sets_lost,
        t1.set_ratio,
        t2.finalist_bucket,
        CASE 
        WHEN t2.finalist_bucket IS NOT NULL THEN 1 ELSE 0
        END AS is_finalist
    FROM tb_league_preliminary_ranking t1
    LEFT JOIN tb_finalist_bucket t2
        ON t1.team_id = t2.team_id 
        AND t1.league_season_id = t2.league_season_id
),

-- the real continuous position 1..n: finalist teams first (gold->QF), then the group stage.
-- prelim_position is the last ORDER BY key, so it breaks the 5-8 tie among quarterfinalists
-- AND orders the group stage (9..n) in one shot
final_ranking 
AS (
    SELECT t1.*,
        ROW_NUMBER() OVER (
            PARTITION BY t1.league_season_id
            ORDER BY t1.is_finalist DESC,
                     t1.finalist_bucket ASC,
                     t1.prelim_position ASC
        ) AS final_rank
    FROM tb_join t1
),

tb_final

AS

(SELECT
    league_season_id AS League_season_id,
    league_id,
    country_code     AS Country_id,
    team_id          AS Team_id,
    league_season,
    prelim_position,
    total_teams_this_season,
    games_won,
    games_lost,
    match_points,
    sets_won,
    sets_lost,
    set_ratio,
    final_rank,
    	finalist_bucket,
    -- strength_level reads the SAME finalist_bucket as final_rank. no elim_rank fallback,
    -- so a team can never be 'quarter_finalist' in one column and 'preliminary_bottom' in the other
    CASE
        WHEN finalist_bucket = 1 THEN 1
        WHEN finalist_bucket = 2 THEN 2
        WHEN finalist_bucket = 3 THEN 3
        WHEN finalist_bucket = 4 THEN 4
        WHEN finalist_bucket = 5 THEN 5
        ELSE 6   -- stayed in the group stage
    END AS strength_level,
    CASE
        WHEN finalist_bucket = 1 THEN 'gold'
        WHEN finalist_bucket = 2 THEN 'silver'
        WHEN finalist_bucket = 3 THEN 'bronze'
        WHEN finalist_bucket = 4 THEN '4th_place'
        WHEN finalist_bucket = 5 THEN 'quarter_finalist'
        ELSE 'regular_season'
    END AS strength_cluster
FROM final_ranking
ORDER BY League_season_id, final_rank)


SELECT *
FROM tb_final