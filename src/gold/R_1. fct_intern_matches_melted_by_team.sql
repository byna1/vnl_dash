WITH
tb_matches_scored AS (
    SELECT
        *,
        CASE WHEN current_home_team_score > current_away_team_score THEN 'W' ELSE 'L' END AS home_result,
        CASE WHEN current_away_team_score > current_home_team_score THEN 'W' ELSE 'L' END AS away_result,
        (CASE WHEN firstSet_home_team_score  > firstSet_away_team_score  THEN 1 ELSE 0 END
    + CASE WHEN second_set_home_team_score > second_set_away_team_score THEN 1 ELSE 0 END
    + CASE WHEN third_set_home_team_score  > third_set_away_team_score  THEN 1 ELSE 0 END
    + CASE WHEN fourth_set_home_team_score > fourth_set_away_team_score THEN 1 ELSE 0 END
    + CASE WHEN fifth_set_home_team_score  > fifth_set_away_team_score  THEN 1 ELSE 0 END) AS home_sets_won,

    (CASE WHEN firstSet_away_team_score  > firstSet_home_team_score  THEN 1 ELSE 0 END
    + CASE WHEN second_set_away_team_score > second_set_home_team_score THEN 1 ELSE 0 END
    + CASE WHEN third_set_away_team_score  > third_set_home_team_score  THEN 1 ELSE 0 END
    + CASE WHEN fourth_set_away_team_score > fourth_set_home_team_score THEN 1 ELSE 0 END
    + CASE WHEN fifth_set_away_team_score  > fifth_set_home_team_score  THEN 1 ELSE 0 END) AS away_sets_won
    
    FROM matches
    WHERE description = 'Finished'
        AND country_name = 'World'
          AND TRIM(REPLACE(league_name, 'Women', '')) IN
          ('Nations League', 'World Championship', 'Olympic Games')

        -- This is the international version, so we are removing the national matches
),

tb_matches_melted AS (
    SELECT
        homeTeam_id AS team_id, 'home' AS team_side, 
        match_id, 
        league_id, 
        league_season,
        country_code, 
        country_name,
         match_week,
        home_sets_won AS sets_won,
        away_sets_won AS sets_lost,
        SUBSTR(match_date,1,16) AS match_date,
        country_code AS league_country_id,
        current_home_team_score AS current_score,
        firstSet_home_team_score AS first_set_score,
        second_set_home_team_score AS second_set_score,
        third_set_home_team_score AS third_set_score,
        fourth_set_home_team_score AS fourth_set_score,
        fifth_set_home_team_score AS fifth_set_score,
        description AS match_status,
        home_result AS team_result
    FROM tb_matches_scored
    UNION ALL
    SELECT
        awayTeam_id AS team_id, 'away' AS team_side, 
        match_id, 
        league_id, 
        league_season,
        country_code, 
        country_name, 
        match_week,
        away_sets_won AS sets_won,
        home_sets_won AS sets_lost,
        SUBSTR(match_date,1,16) AS match_date,
        country_code AS league_country_id,
        current_away_team_score AS current_score,
        firstSet_away_team_score AS first_set_score,
        second_set_away_team_score AS second_set_score,
        third_set_away_team_score AS third_set_score,
        fourth_set_away_team_score AS fourth_set_score,
        fifth_set_away_team_score AS fifth_set_score,
        description AS match_status,
        away_result AS team_result
    FROM tb_matches_scored
),

tb_phase AS (
    SELECT
        *,
        CASE WHEN match_week LIKE '%Final%' OR match_week LIKE '%3rd place%' THEN 'Finals' ELSE 'Preliminary' END AS champ_phase
    FROM tb_matches_melted
),

-- this is for the order of matches.

tb_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY match_date DESC, match_id) AS match_order_general,
        ROW_NUMBER() OVER (PARTITION BY team_id, league_id, league_season ORDER BY match_date DESC, match_id) AS match_order_champ,
        CASE WHEN champ_phase = 'Finals'
             THEN ROW_NUMBER() OVER (PARTITION BY team_id, league_id, league_season, champ_phase ORDER BY match_date DESC, match_id)
             ELSE NULL END AS match_order_finals
    FROM tb_phase
)

SELECT
    team_id AS Team_id,
    CONCAT(league_id, '_', league_season) AS league_season_id,
    match_id,
    team_side,
    match_week,
    champ_phase,
    match_date,
    current_score,
    first_set_score,
    second_set_score,
    third_set_score,
    fourth_set_score,
    fifth_set_score,
    match_status,
    team_result,
    match_order_general,
    match_order_champ,
    match_order_finals,
    sets_won,
    sets_lost
FROM tb_orders
ORDER BY league_season_id, match_id, team_id