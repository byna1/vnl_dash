# %% 

import pandas as pd
import sqlalchemy
import json
from cleaning_formulas import drop_columns, loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver

# %% loading annd loading images also for concatening into the teams granurality



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

