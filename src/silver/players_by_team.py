
# %% 
import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import drop_columns, loading_table_bronze,casting, renaming_columns, json_column_expand, save_db_silver


df = loading_table_bronze("players_by_team")

df = json_column_expand(df,"players")

df = renaming_columns(df)


# %%

df = casting(df)

# %% 

cols_images = [c for c in df.columns if "hash" in c]
images = df[cols_images]

players_by_team = df.drop(columns=images) 

# %%

save_db_silver(images, "tb_images")
save_db_silver(players_by_team,"players_by_team")

