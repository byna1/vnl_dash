# %% 

import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import drop_columns, loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

# %% loading table
matches_statistics = loading_table_bronze("matches_statistics")

# %%
matches_statistics = json_column_expand(matches_statistics,'statistics')

# %% 

cols_to_rename = {
    	'away_team':'away_team_match_score',
        'home_team' : 'home_team_match_score'
        ,

}
matches_statistics = renaming_columns(matches_statistics, cols_to_rename)

# %% 

matches_statistics = casting(matches_statistics)
matches_statistics["set"] = matches_statistics["set"].astype("string")
matches_statistics["category"] = matches_statistics["category"].astype("string")

# %% 

save_db_silver(matches_statistics,"matches_statistics")

matches = loading_table_bronze("matches")

# %% casting 

casting(matches)

# %% droping columns

cols_to_drop= ["tournament_importance",
                "duration","last_period", 
                "home_team_score.display",
                "away_team_score.display", 
                "tournament_name",
                "name",
                "away_team_name",
                "class_name",
                "home_team_name", 	
                "league_name", 
                "round.id",
                "status.type"]  + [i for i in matches.columns if i.__contains__("hash")]


matches = drop_columns(matches, cols_to_drop)


# %% RENAMING COLUMNS


hard_cols = {
"id" : "match_id",
"name" : "match_name",
"home_team_score.current" : "home_team_match_score",
"away_team_score.current" : "away_team_match_score",
}


matches = renaming_columns(matches,hard_cols)



# %%

save_db_silver( matches, "match_info" )


players_by_team = loading_table_bronze("players_by_team")

players_by_team  = json_column_expand(players_by_team ,"players")

# %% DROPING OTHER COLUMNS FOR AUXILIAR TABLE ONLY
players_by_team = players_by_team.drop(columns=[d for d in players_by_team .columns 
                      if d not in ("team_id", "id")])

# %% RENAMING COLUMN

players_by_team  = players_by_team.rename(columns={"id":"player_id"})

# %% CASTING

players_by_team = casting(players_by_team)


# %% SAVING TABLE 

save_db_silver(players_by_team,"players_by_team")

# %% LOADING TABLE

players = loading_table_bronze("players")

# %% DROPING COLUMNS 

players = players.drop(columns=["country_hash_image",
                                "team_hash_image"]) # this are images that repeat themselves


# %% renaming columns
players = renaming_columns(players)
players = players.rename(columns={"id":"player_id", 
                        "hash_image":"player_image"})


# %% CASTING 

players = casting(players)

# %% saving

save_db_silver(players,"players")



teams = loading_table_bronze("teams")
images = loading_table_bronze("players_by_team")
images = images["team_hash_image"]



# %% 


teams = teams.drop(columns=[d for d in teams.columns 
                            if d.__contains__("hash")])

# %%
teams = renaming_columns(teams)

teams = pd.concat([teams,images], axis=1)


teams = teams.rename(columns={"id":"team_id", 
                              "team_hash_image": "team_image"})

# %%

teams = casting(teams)


# %%

save_db_silver(teams,"teams")

