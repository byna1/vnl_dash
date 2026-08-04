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
      AND country_name NOT IN ('World','Europe','South America','North America','Africa','Oceania')
),

-- Sets won by each side
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

-- One row per (team, match): win, match points (3-2-1-0), sets, phase
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
             THEN 'Finals' ELSE 'Regular' END AS champ_phase
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
             THEN 'Finals' ELSE 'Regular' END AS champ_phase
    FROM tb_sets
),

-- Regular-season standings per club-league-season
tb_standings AS (
    SELECT team_id, league_id, league_season, league_season_id,
        SUM(is_win) AS wins, SUM(1 - is_win) AS loses, SUM(match_points) AS points,
        SUM(sets_won) AS sets_won, SUM(sets_lost) AS sets_lost,
        CAST(SUM(sets_won) AS REAL) / NULLIF(SUM(sets_lost), 0) AS set_ratio
    FROM tb_melted
    WHERE champ_phase = 'Regular'
    GROUP BY team_id, league_id, league_season, league_season_id
),

-- Rank within each league-season (FIVB order: wins > points > set ratio)
tb_ranked AS (
    SELECT t1.*,
        ROW_NUMBER() OVER (PARTITION BY t1.league_season_id
                           ORDER BY t1.wins DESC, t1.points DESC, t1.set_ratio DESC) AS rank_position
    FROM tb_standings t1
)

SELECT
    league_season_id AS League_season_id,
    league_id,
    team_id AS Team_id,
    league_season,
    rank_position,
    wins,
    loses,
    points,
    sets_won,
    sets_lost,
    set_ratio
FROM tb_ranked
ORDER BY league_season_id, rank_position