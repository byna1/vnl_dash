WITH

tb_scope

AS

(SELECT
    match_id,
    league_id,
    league_name,
    country_code,
    TRIM(league_season) AS league_season,
    CONCAT(league_id, '_', TRIM(league_season)) AS league_season_id,
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
      AND country_name NOT IN
          ('World','Europe','South America','North America','Africa','Oceania')), -- keeping only real countries: these are the domestic club leagues, the continents/'World' are the international scope


tb_sets AS (
    SELECT t1.*,
        -- counting sets won by home team (direct home-vs-away, no ROW_NUMBER so unplayed NULL sets don't count as phantom wins)
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
    FROM tb_scope t1
),

-- melting table cause the final granularity will be the (league_season, team_id)

tb_melted

AS

(
    SELECT
    match_id,
    league_id,
    league_name,
    country_code,
    league_season,
    league_season_id,
    homeTeam_id AS team_id,
    CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS has_won,

    CASE
            WHEN home_score > away_score AND went_5 = 0 THEN 3
            WHEN home_score > away_score AND went_5 = 1 THEN 2
            WHEN home_score < away_score AND went_5 = 1 THEN 1

    ELSE 0 END AS match_points, -- following the FIVB pattern since is the most used

    home_sets AS sets_won,
    away_sets AS sets_lost
    FROM tb_sets


    UNION ALL


    SELECT
    match_id,
    league_id,
    league_name,
    country_code,
    league_season,
    league_season_id,
    awayTeam_id AS team_id,
    CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS has_won,
    CASE
            WHEN away_score > home_score AND went_5 = 0 THEN 3
            WHEN away_score > home_score AND went_5 = 1 THEN 2
            WHEN away_score < home_score AND went_5 = 1 THEN 1
            ELSE 0 END AS match_points,
    away_sets AS sets_won,
    home_sets AS sets_lost
    FROM tb_sets
),

-- clubs never leave their own league, so there is no finals phase and no not_present: the whole season is one flat standing

tb_prelim

AS

(SELECT
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
GROUP BY team_id, league_id, league_name, country_code, league_season, league_season_id),

-- final position inside each league-season + league size, so the quartile cut is comparable across leagues of different sizes

tb_league_ranking

AS

(SELECT t1.*,
    ROW_NUMBER() OVER (PARTITION BY t1.league_season_id
                       ORDER BY t1.games_won DESC,
                       t1.match_points DESC,
                       t1.set_ratio DESC) AS rank_position,
    COUNT(*) OVER (PARTITION BY t1.league_season_id) AS n_teams
FROM tb_prelim t1)


SELECT
    t1.league_season_id AS League_season_id,
    t1.league_id,
    t1.country_code AS Country_id,
    t1.team_id AS Team_id,
    t1.league_season,
    t1.rank_position,
    t1.n_teams,
    t1.games_won,
    t1.games_lost,
    t1.match_points,
    t1.sets_won,
    t1.sets_lost,
    t1.set_ratio,
    CASE
        WHEN t1.rank_position <= t1.n_teams * 0.25 THEN 1
        WHEN t1.rank_position <= t1.n_teams * 0.50 THEN 2
        WHEN t1.rank_position <= t1.n_teams * 0.75 THEN 3
        ELSE 4 END AS strength_level,
    CASE
        WHEN t1.rank_position <= t1.n_teams * 0.25 THEN 'top_quartile'
        WHEN t1.rank_position <= t1.n_teams * 0.50 THEN 'upper_mid'
        WHEN t1.rank_position <= t1.n_teams * 0.75 THEN 'lower_mid'
        ELSE 'bottom_quartile' END AS strength_cluster -- strength is the quartile of the final position, since clubs have no medals/knockout to rank them by
FROM tb_league_ranking t1
ORDER BY League_season_id, rank_position