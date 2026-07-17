# %%
import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import drop_columns, loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

# %% loading table 

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