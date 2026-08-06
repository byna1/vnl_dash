WITH
tb_scope AS (
    SELECT
        match_id, league_id, TRIM(league_season) AS league_season,
        CONCAT(league_id, '_', TRIM(league_season)) AS league_season_id,
        match_week, homeTeam_id, awayTeam_id,
        current_home_team_score AS home_score,
        current_away_team_score AS away_score,
        firstSet_home_team_score,  firstSet_away_team_score,
        second_set_home_team_score, second_set_away_team_score,
        third_set_home_team_score,  third_set_away_team_score,
        fourth_set_home_team_score, fourth_set_away_team_score,
        fifth_set_home_team_score,  fifth_set_away_team_score,
        CASE WHEN fifth_set_home_team_score IS NOT NULL THEN 1 ELSE 0 END AS went_5
    FROM matches
    WHERE description = 'Finished'
      AND country_name = 'World'
      AND TRIM(REPLACE(league_name, 'Women', '')) IN
          ('Nations League', 'World Championship', 'Olympic Games')
),

-- Sets won by each side, per match
tb_sets AS (
    SELECT t1.*,
        (CASE WHEN firstSet_home_team_score  > firstSet_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_home_team_score > second_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_home_team_score  > third_set_away_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_home_team_score > fourth_set_away_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_home_team_score  > fifth_set_away_team_score  THEN 1 ELSE 0 END) AS home_sets,
        (CASE WHEN firstSet_away_team_score  > firstSet_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN second_set_away_team_score > second_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN third_set_away_team_score  > third_set_home_team_score  THEN 1 ELSE 0 END
       + CASE WHEN fourth_set_away_team_score > fourth_set_home_team_score THEN 1 ELSE 0 END
       + CASE WHEN fifth_set_away_team_score  > fifth_set_home_team_score  THEN 1 ELSE 0 END) AS away_sets
    FROM tb_scope t1
),

-- I chose to put the points as the FIVB, cause its the most used standart for standings

tb_melted AS (
    SELECT match_id, league_id, league_season, league_season_id, match_week,
        homeTeam_id AS team_id,
        CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS is_win,
        CASE
            WHEN home_score > away_score AND went_5 = 0 THEN 3
            WHEN home_score > away_score AND went_5 = 1 THEN 2
            WHEN home_score < away_score AND went_5 = 1 THEN 1
            ELSE 0 END AS match_points,
        home_sets AS sets_won, away_sets AS sets_lost,
        CASE WHEN match_week LIKE '%Final%' OR match_week LIKE '%3rd place%'
                  OR match_week LIKE '%Quarter%' OR match_week LIKE '%Semi%'
             THEN 'Finals' ELSE 'Preliminary' END AS champ_phase
    FROM tb_sets
    UNION ALL
    SELECT match_id, league_id, league_season, league_season_id, match_week,
        awayTeam_id AS team_id,
        CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS is_win,
        CASE
            WHEN away_score > home_score AND went_5 = 0 THEN 3
            WHEN away_score > home_score AND went_5 = 1 THEN 2
            WHEN away_score < home_score AND went_5 = 1 THEN 1
            ELSE 0 END AS match_points,
        away_sets AS sets_won, home_sets AS sets_lost,
        CASE WHEN match_week LIKE '%Final%' OR match_week LIKE '%3rd place%'
                  OR match_week LIKE '%Quarter%' OR match_week LIKE '%Semi%'
             THEN 'Finals' ELSE 'Preliminary' END AS champ_phase
    FROM tb_sets
),

-- Preliminary standings per team-tournament (FIVB order: wins -> points -> set ratio)
tb_prelim AS (
    SELECT team_id, league_id, league_season, league_season_id,
        SUM(is_win) AS wins, SUM(1 - is_win) AS loses, SUM(match_points) AS points,
        SUM(sets_won) AS sets_won, SUM(sets_lost) AS sets_lost,
        CAST(SUM(sets_won) AS REAL) / NULLIF(SUM(sets_lost), 0) AS set_ratio
    FROM tb_melted
    WHERE champ_phase = 'Preliminary'
    GROUP BY team_id, league_id, league_season, league_season_id
),

-- Longer each team went in competitions
tb_knockout AS (
    SELECT team_id, league_season_id,
        MAX(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                      AND match_week NOT LIKE '%Quarter%' AND is_win = 1 THEN 1 ELSE 0 END) AS won_final,
        MAX(CASE WHEN match_week LIKE '%Final%' AND match_week NOT LIKE '%Semi%'
                      AND match_week NOT LIKE '%Quarter%' AND is_win = 0 THEN 1 ELSE 0 END) AS lost_final,
        MAX(CASE WHEN match_week LIKE '%3rd place%' AND is_win = 1 THEN 1 ELSE 0 END) AS won_bronze,
        MAX(CASE WHEN match_week LIKE '%3rd place%' AND is_win = 0 THEN 1 ELSE 0 END) AS lost_bronze,
        MAX(CASE WHEN match_week LIKE '%Quarter%' THEN 1 ELSE 0 END) AS played_qf
    FROM tb_melted
    WHERE champ_phase = 'Finals'
    GROUP BY team_id, league_season_id
),

-- Preliminary rank + knockout flag

tb_ranked AS (
    SELECT t1.*,
        ROW_NUMBER() OVER (PARTITION BY t1.league_season_id
                           ORDER BY t1.wins DESC, t1.points DESC, t1.set_ratio DESC) AS prelim_position,
        CASE WHEN t2.team_id IS NOT NULL THEN 1 ELSE 0 END AS reached_knockout
    FROM tb_prelim t1
    LEFT JOIN tb_knockout t2 ON t1.team_id = t2.team_id AND t1.league_season_id = t2.league_season_id
),

-- Group-eliminated teams: rank + count for median split

tb_split AS (
    SELECT league_season_id, team_id,
        ROW_NUMBER() OVER (PARTITION BY league_season_id
                           ORDER BY wins DESC, points DESC, set_ratio DESC) AS elim_rank,
        COUNT(*) OVER (PARTITION BY league_season_id) AS n_elim
    FROM tb_ranked
    WHERE reached_knockout = 0
),

-- Teams that actually played, with their strength level/cluster

tb_played AS (
    SELECT
        t1.league_season_id, t1.league_id, t1.team_id, t1.league_season,
        t1.wins, t1.loses, t1.points, t1.sets_won, t1.sets_lost, t1.set_ratio, t1.prelim_position,
        CASE
            WHEN t2.won_final = 1 THEN 1
            WHEN t2.lost_final = 1 THEN 2
            WHEN t2.won_bronze = 1 THEN 3
            WHEN t2.lost_bronze = 1 THEN 4
            WHEN t2.played_qf = 1 THEN 5
            WHEN t3.elim_rank <= t3.n_elim / 2 THEN 6
            ELSE 7 END AS strength_level,
        CASE
            WHEN t2.won_final = 1 THEN 'gold'
            WHEN t2.lost_final = 1 THEN 'silver'
            WHEN t2.won_bronze = 1 THEN 'bronze'
            WHEN t2.lost_bronze = 1 THEN '4th_place'
            WHEN t2.played_qf = 1 THEN 'quarter_finalist'
            WHEN t3.elim_rank <= t3.n_elim / 2 THEN 'preliminary_top'
            ELSE 'preliminary_bottom' END AS strength_cluster
    FROM tb_ranked t1
    LEFT JOIN tb_knockout t2 ON t1.team_id = t2.team_id AND t1.league_season_id = t2.league_season_id
    LEFT JOIN tb_split t3 ON t1.team_id = t3.team_id AND t1.league_season_id = t3.league_season_id
),

-- National leagues by country + gender (gender derived from league name)
tb_nat_leagues AS (
    SELECT DISTINCT
        country_code AS country_id,
        CASE WHEN league_name LIKE '%Women%' THEN 'Women' ELSE 'Men' END AS naipe
    FROM matches
    WHERE country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')
),

-- National teams (name = country), with gender
tb_nat_teams AS (
    SELECT DISTINCT
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
        AND t2.country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')
),

-- Eligible teams: national team whose country has a national league of the SAME gender
tb_universe AS (
    SELECT DISTINCT t1.team_id
    FROM tb_nat_teams t1
    INNER JOIN tb_nat_leagues t2
        ON t1.country_id = t2.country_id AND t1.naipe = t2.naipe
),

-- All international tournament-seasons present in the data
tb_tournaments AS (
    SELECT DISTINCT league_season_id, league_id, league_season
    FROM tb_melted
),

-- Every eligible team crossed with every tournament-season (ids carry gender, so cross is gender-safe)
tb_grid AS (
    SELECT t1.team_id, t2.league_season_id, t2.league_id, t2.league_season
    FROM tb_universe t1
    CROSS JOIN tb_tournaments t2
),

-- Left join played onto the grid; teams with no match that season = not_present

tb_final AS (
    SELECT
        t1.league_season_id AS League_season_id,
        t1.team_id AS Team_id,
        t2.prelim_position AS rank_position,
        COALESCE(t2.wins, 0)  AS wins,
        COALESCE(t2.loses, 0) AS loses,
        COALESCE(t2.points, 0) AS points,
        COALESCE(t2.sets_won, 0) AS sets_won,
        COALESCE(t2.sets_lost, 0) AS sets_lost,
        t2.set_ratio,
        COALESCE(t2.strength_level, 8) AS strength_level,
        COALESCE(t2.strength_cluster, 'not_present') AS strength_cluster,
        CASE 
            WHEN strength_cluster IN ('gold', 'silver', 'bronze') THEN 'podium'
            WHEN strength_cluster IN ('preliminary_top', 'preliminary_bottom') THEN 'preliminary'
            WHEN strength_cluster IN ('4th_place', '4th_place') THEN '4th_place'
            ELSE 'not_present'
        END AS grouped_strenght_cluster
    FROM tb_grid t1
    LEFT JOIN tb_played t2
        ON t1.team_id = t2.team_id AND t1.league_season_id = t2.league_season_id
)

SELECT *
FROM tb_final
ORDER BY League_season_id, strength_level, rank_position