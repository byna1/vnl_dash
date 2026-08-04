WITH
tb_scope AS (
    SELECT t1.*
    FROM matches t1
    INNER JOIN leagues t2 
    ON t1.league_id = t2.league_id
    WHERE t1.description = 'Finished'
      AND TRIM(REPLACE(t1.league_name, 'Women', '')) IN
          ('Nations League', 'World Championship', 'Olympic Games')
), -- filtering by the international championships we are working with. 
-- this was done because in the league table there are ex. Nationas League Women

-- match result and winners per ser

tb_matches_scored AS (
    SELECT
        match_id, league_id, TRIM(league_season) AS league_season, match_week,
        homeTeam_id, awayTeam_id,
        current_home_team_score, current_away_team_score,
        firstSet_home_team_score,  firstSet_away_team_score,
        second_set_home_team_score, second_set_away_team_score,
        third_set_home_team_score,  third_set_away_team_score,
        fourth_set_home_team_score, fourth_set_away_team_score,
        fifth_set_home_team_score,  fifth_set_away_team_score,

        -- total sets won by each side
        (CASE WHEN firstSet_home_team_score  > firstSet_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_home_team_score > second_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_home_team_score  > third_set_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_home_team_score > fourth_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_home_team_score  > fifth_set_away_team_score  THEN 1 ELSE 0 END) AS home_sets_won,
        (CASE WHEN firstSet_away_team_score  > firstSet_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_away_team_score > second_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_away_team_score  > third_set_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_away_team_score > fourth_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_away_team_score  > fifth_set_home_team_score  THEN 1 ELSE 0 END) AS away_sets_won,
        -- win flags per side
        CASE WHEN firstSet_home_team_score  > firstSet_away_team_score  THEN 1 ELSE 0 END AS h_set1,
        CASE WHEN firstSet_away_team_score  > firstSet_home_team_score  THEN 1 ELSE 0 END AS a_set1,
        CASE WHEN second_set_home_team_score > second_set_away_team_score THEN 1 ELSE 0 END AS h_set2,
        CASE WHEN second_set_away_team_score > second_set_home_team_score THEN 1 ELSE 0 END AS a_set2,
        CASE WHEN third_set_home_team_score  > third_set_away_team_score  THEN 1 ELSE 0 END AS h_set3,
        CASE WHEN third_set_away_team_score  > third_set_home_team_score  THEN 1 ELSE 0 END AS a_set3,
        CASE WHEN fourth_set_home_team_score > fourth_set_away_team_score THEN 1 ELSE 0 END AS h_set4,
        CASE WHEN fourth_set_away_team_score > fourth_set_home_team_score THEN 1 ELSE 0 END AS a_set4,
        CASE WHEN fifth_set_home_team_score  > fifth_set_away_team_score  THEN 1 ELSE 0 END AS h_set5,
        CASE WHEN fifth_set_away_team_score  > fifth_set_home_team_score  THEN 1 ELSE 0 END AS a_set5,
        -- tight sets, a tight set is a set won with <3 points difference
        (CASE WHEN ABS(firstSet_home_team_score  - firstSet_away_team_score)  <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(second_set_home_team_score - second_set_away_team_score) <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(third_set_home_team_score  - third_set_away_team_score)  <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(fourth_set_home_team_score - fourth_set_away_team_score) <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(fifth_set_home_team_score  - fifth_set_away_team_score)  <= 3 THEN 1 ELSE 0 END) AS n_tight_sets
    FROM tb_scope
),

-- melting the matches table to make it one team per row
matches_melted AS (
    SELECT
        match_id, homeTeam_id AS team_id, league_id, league_season, match_week,
        firstSet_home_team_score  AS first_set_score,
        second_set_home_team_score AS second_set_score,
        third_set_home_team_score  AS third_set_score,
        fourth_set_home_team_score AS fourth_set_score,
        fifth_set_home_team_score  AS fifth_set_score,
        CASE WHEN current_home_team_score > current_away_team_score THEN 'W' ELSE 'L' END AS team_result,
        h_set1 AS s1, h_set2 AS s2, h_set3 AS s3, h_set4 AS s4, h_set5 AS s5,
        n_tight_sets
    FROM tb_matches_scored
    UNION ALL
    SELECT
        match_id, awayTeam_id AS team_id, league_id, league_season, match_week,
        firstSet_away_team_score  AS first_set_score,
        second_set_away_team_score AS second_set_score,
        third_set_away_team_score  AS third_set_score,
        fourth_set_away_team_score AS fourth_set_score,
        fifth_set_away_team_score  AS fifth_set_score,
        CASE WHEN current_away_team_score > current_home_team_score THEN 'W' ELSE 'L' END AS team_result,
        a_set1 AS s1, a_set2 AS s2, a_set3 AS s3, a_set4 AS s4, a_set5 AS s5,
        n_tight_sets
    FROM tb_matches_scored
),

-- Season totals
team_games_stats AS (
    SELECT
        league_id,
        team_id,
        TRIM(league_season) AS league_season,
        total_games_played,
        total_games_wins,
        total_games_loses,
        total_points_scored,
        total_points_received,
        total_points_scored - total_points_received AS delta_points
    FROM team_stats
),

-- count of 5 sets per season
tb_count_match_week AS (
    SELECT
        team_id,
        league_season,
        COUNT(CASE WHEN fifth_set_score IS NOT NULL THEN 1 END) AS total_games_5_sets,
        COUNT(CASE WHEN match_week = 'Final' THEN 1 END) AS total_finals,
        COUNT(CASE WHEN match_week = 'Semi-finals' THEN 1 END) AS total_semi_finals,
        COUNT(CASE WHEN match_week = '3rd place' THEN 1 END) AS total_3rd_place_dispute,
        COUNT(CASE WHEN match_week = 'Quarter-finals' THEN 1 END) AS total_4r_finals_appearances
    FROM matches_melted
    GROUP BY team_id, league_season
),

-- 3x0 wins per season per team
tb_3x0_wins AS (
    SELECT
        team_id,
        league_season,
        SUM(CASE WHEN team_result = 'W' AND fourth_set_score IS NULL THEN 1 ELSE 0 END) AS n_3_x_0_wins
    FROM matches_melted
    GROUP BY team_id, league_season
),

-- sets won per set number
tb_sets_won AS (
    SELECT
        team_id,
        league_season,
        SUM(s1) AS set_1_win,
        SUM(s2) AS set_2_win,
        SUM(s3) AS set_3_win,
        SUM(s4) AS set_4_win,
        SUM(s5) AS set_5_win
    FROM matches_melted
    GROUP BY team_id, league_season
),

-- number of tight games won per team per season
tb_tight_games AS (
    SELECT
        team_id,
        league_season,
        COUNT(*) AS n_tight_games_won
    FROM matches_melted
    WHERE team_result = 'W'
      AND n_tight_sets >= 3
    GROUP BY team_id, league_season
),

-- making everything one row per team season 
tb_join AS (
    SELECT
        t1.team_id AS Team_id,
        CONCAT(t1.league_id, '_', t1.league_season) AS league_season_id,
        t1.league_id,
        t1.league_season,
        t1.total_games_played AS season_games_played,
        t1.total_games_wins   AS season_games_won,
        t1.total_games_loses  AS season_games_lost,
        t1.total_points_scored   AS points_scored,
        t1.total_points_received AS points_received,
        t1.delta_points          AS points_delta,
        COALESCE(t2.total_finals, 0)                AS total_finals,
        COALESCE(t2.total_semi_finals, 0)           AS total_semi_finals,
        COALESCE(t2.total_3rd_place_dispute, 0)     AS total_3rd_place_dispute,
        COALESCE(t2.total_4r_finals_appearances, 0) AS total_4r_finals_appearances,
        COALESCE(t2.total_games_5_sets, 0)          AS total_games_5_sets,
        COALESCE(t3.n_3_x_0_wins, 0)                AS n_3_x_0_wins,
        COALESCE(t4.set_1_win, 0)                   AS set_1_win,
        COALESCE(t4.set_2_win, 0)                   AS set_2_win,
        COALESCE(t4.set_3_win, 0)                   AS set_3_win,
        COALESCE(t4.set_4_win, 0)                   AS set_4_win,
        COALESCE(t4.set_5_win, 0)                   AS set_5_win,
        COALESCE(t5.n_tight_games_won, 0)           AS n_tight_games_won
    FROM team_games_stats AS t1
    LEFT JOIN tb_count_match_week AS t2
        ON t1.team_id = t2.team_id AND t1.league_season = t2.league_season
    LEFT JOIN tb_3x0_wins AS t3
        ON t1.team_id = t3.team_id AND t1.league_season = t3.league_season
    LEFT JOIN tb_sets_won AS t4
        ON t1.team_id = t4.team_id AND t1.league_season = t4.league_season
    LEFT JOIN tb_tight_games AS t5
        ON t1.team_id = t5.team_id AND t1.league_season = t5.league_season
)

SELECT *
FROM tb_join
ORDER BY Team_id, league_season_id