WITH

tb_universe

AS

(SELECT 
    CONCAT(league_id, '_', TRIM(league_season)) AS League_season_id,
    match_id, 
    league_id, 
    TRIM(league_season) AS league_season,
    CASE 
            WHEN league_name LIKE '%Women%' THEN 'Women' 
            WHEN league_name LIKE '%Femenina%' THEN 'Women'
            WHEN league_name LIKE '%Female%' THEN 'Women'
            WHEN league_name LIKE '%Feminina%' THEN 'Women' 
    ELSE 'Men' END AS league_naipe,
    match_week, 
    homeTeam_id, 
    awayTeam_id,
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
    CASE 
        WHEN fifth_set_home_team_score IS NOT NULL THEN 1 ELSE 0 
    END AS went_5
FROM matches
WHERE description = 'Finished'    
      AND country_name = 'World'
      AND TRIM(REPLACE(league_name, 'Women', '')) IN
          ('Nations League', 'World Championship', 'Olympic Games')), -- selecting just the championships that we are analysing


tb_sets AS (
    SELECT t1.*,
        -- couting sets won  by home team
        (CASE WHEN firstSet_home_team_score  > firstSet_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_home_team_score > second_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_home_team_score  > third_set_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_home_team_score > fourth_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_home_team_score  > fifth_set_away_team_score  THEN 1 ELSE 0 END) AS home_sets,
        -- counting sets won by away team
        (CASE WHEN firstSet_away_team_score  > firstSet_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_away_team_score > second_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_away_team_score  > third_set_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_away_team_score > fourth_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_away_team_score  > fifth_set_home_team_score  THEN 1 ELSE 0 END) AS away_sets
    FROM tb_universe t1
),

-- melting table cause the final granularity will be the (league_season, team_id)

tb_melted

AS 

(
    SELECT 
    match_id, 
    league_id,
    league_naipe,
    league_season, 
    league_season_id, 
    match_week,
    homeTeam_id AS team_id,
    CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS has_won,
    
    CASE
            WHEN home_score > away_score AND went_5 = 0 THEN 3
            WHEN home_score > away_score AND went_5 = 1 THEN 2
            WHEN home_score < away_score AND went_5 = 1 THEN 1
    
    ELSE 0 END AS match_points, -- following the FIVB pattern since is the most used. 

    home_sets AS sets_won, 
    away_sets AS sets_lost,
    CASE 
    
        WHEN 
            match_week LIKE '%Final%' OR match_week LIKE '%3rd place%'
            OR match_week LIKE '%Quarter%' 
            OR match_week LIKE '%Semi%'
            THEN 'Finals' 
            ELSE 'Preliminary' END AS champ_phase -- considering the finals as the ones we can easily identify since multiple championships have multiple formats
    FROM tb_sets


    UNION ALL


    SELECT 
    
        match_id, 
        league_id,
        league_naipe, 
        league_season, 
        league_season_id, 
        match_week,
        awayTeam_id AS team_id,
        CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS has_won,
        CASE
            WHEN away_score > home_score AND went_5 = 0 THEN 3
            WHEN away_score > home_score AND went_5 = 1 THEN 2
            WHEN away_score < home_score AND went_5 = 1 THEN 1
            ELSE 0 END AS match_points,
        away_sets AS sets_won, 
        home_sets AS sets_lost,
        CASE WHEN match_week LIKE '%Final%' 
            OR match_week LIKE '%3rd place%'
            OR match_week LIKE '%Quarter%' 
            OR match_week LIKE '%Semi%'
            THEN 'Finals' 
        ELSE 'Preliminary' END AS champ_phase
    FROM tb_sets
),

tb_prelim

AS

(SELECT
    team_id,
    league_season_id,
    SUM(has_won) AS games_won, 
    SUM(match_points) AS match_points,
    SUM(sets_won) AS sets_won,
    SUM(sets_lost) AS sets_lost,
    CAST(SUM(sets_won) AS FLOAT) / NULLIF(SUM(sets_lost), 0) AS set_ratio
FROM tb_melted
WHERE champ_phase = 'Preliminary'
GROUP BY  team_id, league_season_id),

tb_finals

AS

(SELECT 
    team_id, 
    league_season_id,
        MAX(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
            AND match_week NOT LIKE '%Quarter%' AND has_won = 1 THEN 1 ELSE 0 END) AS won_final,
        MAX(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                      AND match_week NOT LIKE '%Quarter%' AND has_won = 0 THEN 1 ELSE 0 END) AS lost_final,
        MAX(CASE WHEN match_week LIKE '%3rd place%' AND has_won = 1 THEN 1 ELSE 0 END) AS won_bronze,
        MAX(CASE WHEN match_week LIKE '%3rd place%' AND has_won = 0 THEN 1 ELSE 0 END) AS lost_bronze,
        MAX(CASE WHEN match_week LIKE '%Quarter%' THEN 1 ELSE 0 END) AS played_qf
FROM tb_melted
WHERE champ_phase = 'Finals'
GROUP BY team_id, league_season_id),

tb_prel_ranking

AS

(SELECT t1.*,
        ROW_NUMBER() OVER (PARTITION BY t1.league_season_id
                           ORDER BY t1.games_won DESC, 
                           t1.match_points DESC, t1.set_ratio DESC) AS prelim_position,
        CASE 
            WHEN t2.team_id IS NOT NULL THEN 1 ELSE 0 
        END AS reached_finals
FROM tb_prelim t1
LEFT JOIN tb_finals t2 
ON t1.team_id = t2.team_id 
AND t1.league_season_id = t2.league_season_id),

tb_eliminated_ranking

AS

(SELECT 
    league_season_id, 
    team_id,
    ROW_NUMBER() OVER (PARTITION BY league_season_id
                           ORDER BY games_won DESC, 
                           match_points DESC, 
                           set_ratio DESC) AS elim_rank,
    COUNT(*) OVER (PARTITION BY league_season_id) AS n_elim
    FROM tb_prel_ranking
WHERE reached_finals = 0
),

-- turning the standings into a strength level: 1 = gold ... 7 = preliminary_bottom (8 = not_present comes later)

tb_team_strength

AS

(SELECT 
    t1.league_season_id,
    t1.team_id,
    t1.prelim_position,
    t1.games_won,
    t1.match_points,
    t1.sets_won,
    t1.sets_lost,
    t1.set_ratio,
    CASE
        WHEN t2.won_final = 1 THEN 1
        WHEN t2.lost_final = 1 THEN 2
        WHEN t2.won_bronze = 1 THEN 3
        WHEN t2.lost_bronze = 1 THEN 4
        WHEN t2.played_qf = 1 THEN 5
        WHEN t3.elim_rank <= t3.n_elim / 2 THEN 6 -- top half of the teams that stayed in the group stage
        ELSE 7 END AS strength_level,
    CASE
        WHEN t2.won_final = 1 THEN 'gold'
        WHEN t2.lost_final = 1 THEN 'silver'
        WHEN t2.won_bronze = 1 THEN 'bronze'
        WHEN t2.lost_bronze = 1 THEN '4th_place'
        WHEN t2.played_qf = 1 THEN 'quarter_finalist'
        WHEN t3.elim_rank <= t3.n_elim / 2 THEN 'preliminary_top'
        ELSE 'preliminary_bottom' END AS strength_cluster
FROM tb_prel_ranking t1
LEFT JOIN tb_finals t2 
ON t1.team_id = t2.team_id 
AND t1.league_season_id = t2.league_season_id
LEFT JOIN tb_eliminated_ranking t3 
ON t1.team_id = t3.team_id 
AND t1.league_season_id = t3.league_season_id),

-- countries that actually run a domestic league, split by naipe

tb_nat_leagues

AS

(SELECT DISTINCT
    country_code AS country_id,
    CASE WHEN league_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS naipe
FROM matches
WHERE country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')), -- continents and 'World' are not real countries, so they can't hold a domestic league

-- national teams (team name matches a country name), carrying the naipe

tb_nat_teams

AS

(SELECT DISTINCT
    t1.homeTeam_id AS team_id,
    t2.country_code AS country_id,
    CASE WHEN t1.homeTeam_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS naipe
FROM matches t1
INNER JOIN countries t2
    ON TRIM(REPLACE(t1.homeTeam_name, 'Women', '')) = t2.country_name
    AND t2.country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')

UNION

SELECT DISTINCT
    t1.awayTeam_id AS team_id,
    t2.country_code AS country_id,
    CASE WHEN t1.awayTeam_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS naipe
FROM matches t1
INNER JOIN countries t2
    ON TRIM(REPLACE(t1.awayTeam_name, 'Women', '')) = t2.country_name
    AND t2.country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')),

-- eligible teams: a national team only enters the analysis if its country has a domestic league of the SAME naipe

tb_eligible_teams

AS

(SELECT DISTINCT 
    t1.team_id,
    t1.naipe
FROM tb_nat_teams t1
INNER JOIN tb_nat_leagues t2
    ON t1.country_id = t2.country_id 
    AND t1.naipe = t2.naipe),

-- every tournament-season we have, keeping its naipe so we can match teams by gender

tb_tournaments

AS

(SELECT DISTINCT 
    league_season_id,
    league_naipe
FROM tb_melted),

-- grid of who SHOULD be in each tournament: join by naipe so a team is only expected in editions of its own gender
-- this INNER JOIN (instead of a cross join) is what stops women teams leaking as not_present in men tournaments and vice versa

tb_grid

AS

(SELECT 
    t1.team_id,
    t2.league_season_id
FROM tb_eligible_teams t1
INNER JOIN tb_tournaments t2
    ON t1.naipe = t2.league_naipe)


SELECT 
    t1.league_season_id AS League_season_id,
    t1.team_id AS Team_id,
    t2.prelim_position AS rank_position,
    COALESCE(t2.games_won, 0)   AS games_won,
    COALESCE(t2.match_points, 0) AS match_points,
    COALESCE(t2.sets_won, 0)    AS sets_won,
    COALESCE(t2.sets_lost, 0)   AS sets_lost,
    t2.set_ratio,
    COALESCE(t2.strength_level, 8)              AS strength_level,
    COALESCE(t2.strength_cluster, 'not_present') AS strength_cluster -- eligible team that skipped this edition gets the worst level, penalizing inconsistency across the years
FROM tb_grid t1
LEFT JOIN tb_team_strength t2
    ON t1.team_id = t2.team_id 
    AND t1.league_season_id = t2.league_season_id
ORDER BY League_season_id, strength_level, rank_position