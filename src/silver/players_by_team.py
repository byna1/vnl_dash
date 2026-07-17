
# %% 
import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import drop_columns, loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

# LOADING TABLE

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

