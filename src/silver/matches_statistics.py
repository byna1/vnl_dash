# %% 

import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

# %%
df = loading_table_bronze("matches_statistics")

# %%
df = json_column_expand(df,'statistics')

# %% 

cols_to_rename = {
    	'away_team':'away_team_match_score',
        'home_team' : 'home_team_match_score'
        ,

}
df = renaming_columns(df, cols_to_rename)

# %% 

df = casting(df)
df["set"] = df["set"].astype("string")
df["category"] = df["category"].astype("string")

# %% 

save_db_silver(df,"matches_statistics")
