# %%
import pandas as pd
import sqlalchemy as sql

# %%

engine_bronze = 'sqlite:///../../data/bronze/db_bronze.db'

con_bronze = sql.create_engine(engine_bronze)


# reading

query = 'SELECT * FROM matches'

df = pd.read_sql(query,con=con_bronze)

# %% CASTING

for n in df.columns:
    # dropping the agregations
    if "avg" in n or "average" in n or "percent" in n:
        df = df.drop(columns=n)

    #converting scores and ids to int
    elif "score" in n or "id" in n:
        df[n] = (pd.to_numeric(df[n],
                    errors="coerce")
                    .astype("Int64")
                )
    # converting types and names to string
    elif n.endswith("name") or n.__contains__("type"):
        df[n] = df[n].astype("string")


# %% DROPPING COLUMNS

drop_columns = ["tournament_importance",
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
                "status.type"]  + [i for i in df.columns if i.__contains__("image")]

df = df.drop(columns=drop_columns,
              errors="ignore")

# %% RENAMING COLUMNS

cols= {}


for n in df.columns: 
    cols[n] = (n.replace(".","_")
                .replace("period","set"))


hard_cols = {
"id" : "match_id",
"name" : "match_name",
"home_team_score.current" : "home_team_match_score",
"away_team_score.current" : "away_team_match_score",
}


cols.update(hard_cols)

df_renamed = df.rename(columns=cols)


# %% 

match_info = pd.concat((df_renamed["times_specific_start_time"], 
                        df_renamed.iloc[:,:18]),
                       axis=1)


match_points = pd.concat((df_renamed["match_id"],
                          df_renamed.iloc[:,18:30]),
                          axis=1)

# %%


engine_silver = 'sqlite:///../../data/silver/db_silver.db'

con_silver = sql.create_engine(engine_silver)

match_info.to_sql('match_info', con=con_silver, if_exists='replace', index=False)
match_points.to_sql('match_points', con=con_silver, if_exists='replace', index=False)