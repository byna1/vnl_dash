WITH

tb_leagues_inter

AS

(SELECT
    t4.country_id,
    t2.league_id,
    t3.league_name,
    t3.league_naipe,
    t1.*
FROM fct_intern_standings t1
LEFT JOIN dim_season t2
ON t1.League_season_id = t2.League_season_id
LEFT JOIN dim_leagues t3
ON t2.league_id = t3.league_id
LEFT JOIN dim_teams t4
ON t1.team_id = t4.Team_id),

tb_leagues_nat

AS

(SELECT
    t3.country_id,
    t2.league_id,
    t3.league_name,
    t3.league_naipe,
    t1.*
FROM fct_national_standings t1
LEFT JOIN dim_season t2
ON t1.League_season_id = t2.League_season_id
LEFT JOIN dim_leagues t3
ON t2.league_id = t3.league_id
LEFT JOIN dim_teams t4
ON t1.team_id = t4.Team_id),

tb_avg

AS

(SELECT
    country_id,
    league_naipe,
AVG(strength_level) AS forca_selecao
FROM tb_leagues_inter
GROUP BY country_id, league_naipe),

tb_count_leagues

AS

(SELECT
    country_id,
    league_naipe,
COUNT(DISTINCT league_id) AS qtd_national_leagues,
COUNT(DISTINCT team_id) AS qtd_clubs
FROM tb_leagues_nat
GROUP BY country_id, league_naipe),

tb_avg_tight_sets

AS

(SELECT
    t3.country_id,
    t3.league_naipe,
AVG(t1.n_tight_sets) AS avg_tight_sets
FROM fct_national_matches t1
LEFT JOIN dim_season t2
ON t1.League_season_id = t2.league_season_id
LEFT JOIN dim_leagues t3
ON t2.league_id = t3.league_id
GROUP BY t3.country_id, t3.league_naipe)


SELECT
    t1.country_id,
    t1.league_naipe,
    COALESCE(t3.forca_selecao, 8) AS nat_team_strenght,
    t1.qtd_national_leagues,
    t1.qtd_clubs,
    t2.avg_tight_sets
FROM tb_count_leagues t1
LEFT JOIN tb_avg_tight_sets t2
ON t1.country_id = t2.country_id
AND t1.league_naipe = t2.league_naipe
LEFT JOIN tb_avg t3
ON t1.country_id = t3.country_id
AND t1.league_naipe = t3.league_naipe
ORDER BY t1.league_naipe, nat_team_strenght, avg_tight_sets DESC, qtd_clubs DESC