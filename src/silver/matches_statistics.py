# %% 

import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

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
