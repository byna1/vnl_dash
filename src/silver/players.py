# %% 

import pandas as pd
import sqlalchemy
import json
from cleaning_formulas import drop_columns, loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

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

