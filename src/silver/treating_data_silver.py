# %%
import pandas as pd 
import sqlalchemy
import json
from cleaning_formulas import loading_table_bronze, json_column_expand, casting, renaming_columns, save_db_silver


# %% loading columns

leagues = loading_table_bronze("leagues")

matches = loading_table_bronze("matches")

team_stats = loading_table_bronze("team_stats")

teams = loading_table_bronze("teams")

standings = loading_table_bronze("standings")



# %% expanding json
leagues = json_column_expand(leagues,"seasons")


standings = json_column_expand(standings,"groups")


standings = json_column_expand(standings,"standings")

# %% renaming columns


