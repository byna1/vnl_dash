WITH
tb_match AS (
    SELECT
        match_id AS Match_id,
        CONCAT(league_id, '_', TRIM(league_season)) AS league_season_id,
        match_week,
        SUBSTR(match_date,1,16) AS match_date,
        homeTeam_id,
        awayTeam_id,
        description AS match_status,
        current_home_team_score,
        current_away_team_score,
        firstSet_home_team_score,  firstSet_away_team_score,
        second_set_home_team_score, second_set_away_team_score,
        third_set_home_team_score,  third_set_away_team_score,
        fourth_set_home_team_score, fourth_set_away_team_score,
        fifth_set_home_team_score,  fifth_set_away_team_score,
        country_code,
        country_name
    FROM matches
    WHERE description = 'Finished'
        AND country_name NOT IN ('Europe','South America','North America','Africa','Oceania')
        AND country_code <> 'World'   -- NATIONAL
),

tb_deltas AS (
    SELECT
        Match_id,
        CASE WHEN current_home_team_score > current_away_team_score
             THEN homeTeam_id ELSE awayTeam_id END AS match_winner,
        (CASE WHEN firstSet_home_team_score  IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN second_set_home_team_score IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN third_set_home_team_score  IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_home_team_score IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_home_team_score  IS NOT NULL THEN 1 ELSE 0 END) AS total_sets,
        (CASE WHEN ABS(firstSet_home_team_score  - firstSet_away_team_score)  <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(second_set_home_team_score - second_set_away_team_score) <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(third_set_home_team_score  - third_set_away_team_score)  <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(fourth_set_home_team_score - fourth_set_away_team_score) <= 3 THEN 1 ELSE 0 END
       + CASE WHEN ABS(fifth_set_home_team_score  - fifth_set_away_team_score)  <= 3 THEN 1 ELSE 0 END) AS n_tight_sets
    FROM tb_match
),

tb_join AS (
    SELECT
        t1.Match_id,
        t1.league_season_id,
        t1.match_week,
        t1.country_name,
        t1.country_code,
        t1.match_date,
        t1.homeTeam_id,
        t1.awayTeam_id,
        t2.match_winner,
        t1.match_status,
        t1.current_home_team_score,
        t1.current_away_team_score,
        t1.firstSet_home_team_score,  t1.firstSet_away_team_score,
        t1.second_set_home_team_score, t1.second_set_away_team_score,
        t1.third_set_home_team_score,  t1.third_set_away_team_score,
        t1.fourth_set_home_team_score, t1.fourth_set_away_team_score,
        t1.fifth_set_home_team_score,  t1.fifth_set_away_team_score,
        t2.total_sets,
        t2.n_tight_sets
    FROM tb_match t1
    LEFT JOIN tb_deltas t2
        ON t1.Match_id = t2.Match_id
)

SELECT *
FROM tb_join
ORDER BY Match_id