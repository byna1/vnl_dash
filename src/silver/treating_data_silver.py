# %%
import pandas as pd 
import sqlalchemy
import json
from src.silver.cleaning_formulas import column_expand,drop_columns, loading_table_bronze, json_column_expand, casting, renaming_columns, save_db_silver
pd.set_option("display.max_columns", None)


# %%
def main():
# %% loading columns

    leagues = loading_table_bronze("leagues")

    matches = loading_table_bronze("matches")

    teams = loading_table_bronze("teams")

    team_stats = loading_table_bronze("team_stats")

    standings = loading_table_bronze("standings")

    countries = loading_table_bronze ("countries")

    # %% expanding json
    leagues = json_column_expand(leagues,"seasons")


    standings = json_column_expand(standings,"groups")


    standings = json_column_expand(standings,"standings")

    # %% renaming columns

    c_rename = {
        "code":"country_code",
        "name": "country_name",
        "logo": "country_logo"
    }
    countries = renaming_columns(countries,c_rename)
    # %%

    l_rename = {
        "id" : "league_id",
        "logo" : "league_logo",
        "state.description" : "match_status",
        "name" : "league_name",
        "season" : "league_season",
    }


    leagues = renaming_columns(leagues,l_rename)

    # %% 

    m_rename = {
        "id" : "match_id",
        "logo" : "league_logo",
        "week" : "match_week",
        "date" : "match_date",
        "current" :"current score",
        }

    matches = renaming_columns(matches,m_rename)



    # %% 

    teams_rename = { 
    "id": "team_id",
    "logo": "team_logo",
    "name" : "team_name"
    ,
    }

    teams = renaming_columns(teams,teams_rename)


    t_stats_rename = { 
    "leagueId": "league_id",
    "leagueName": "league_name",

    }
    team_stats = renaming_columns(team_stats,t_stats_rename)

    # %%

    standings_rename = { 
    "name": "season_name",
    "leagueName" : "league_name",
    "gamesPlayed" : "games_played", 
    "scoredPoints" : "scored_points",
    "receivedPoints" : "received_points",
    "position" : "standing_position",

    }

    standings = renaming_columns(standings,standings_rename)

    # %% expanding columns

    column_expand(matches, "current", 
                "current_home_team_score", 
                "current_away_team_score")

    # %%

    column_expand(matches, "firstSet", 
                "firstSet_home_team_score",
                "firstSet_away_team_score")

    column_expand(matches, "secondSet", 
                "second_set_home_team_score",
                "second_set_away_team_score")

    column_expand(matches, "thirdSet", 
                "third_set_home_team_score",
                "third_set_away_team_score")


    column_expand(matches, "fourthSet", 
                "fourth_set_home_team_score",
                "fourth_set_away_team_score")


    column_expand(matches, "fifthSet", 
                "fifth_set_home_team_score",
                "fifth_set_away_team_score")

    # Dropping columns

    matches = drop_columns(matches, ["current", 
                        "firstSet", 
                        "secondSet", 
                        "thirdSet",
                        "fourthSet", 
                        "fifthSet"])

    # %%


    casting(leagues)
    casting(matches)
    casting(teams)
    casting(team_stats)
    casting(standings)
    casting(countries)

     # %%

    save_db_silver(leagues, "leagues")
    save_db_silver(matches, "matches")
    save_db_silver(teams, "teams")
    save_db_silver(team_stats, "team_stats")
    save_db_silver(standings, "standings")
    save_db_silver(countries,"countries")


if __name__ == main():
    main()
