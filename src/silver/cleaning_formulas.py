# %%
import pandas as pd
import sqlalchemy as sql
import json

# reading
def loading_table_bronze(table_name):
    engine_bronze = 'sqlite:///../../data/bronze/db_bronze.db'
    con = sql.create_engine(engine_bronze)
    query = f'SELECT * FROM {table_name}'
    df = pd.read_sql(query, con=con)
    return df

# %% CASTING
def casting(df):
    for n in df.columns:
        # dropping the agregations
        if "avg" in n or "average" in n or "percent" in n:
            df = df.drop(columns=n)

        #converting scores and ids to int
        elif "score" in n or "id" in n or "number" in n:
            df[n] = (pd.to_numeric(df[n],
                        errors="coerce")
                        .astype("Int64")
                    )
        # converting types and names to string
        elif n.endswith("name") or n.__contains__("type") or n.__contains__("category"):
            df[n] = df[n].astype("string")

        elif n.__contains__("date"):
            df[n] = pd.to_datetime(df[n], errors="coerce")
    return df


# %% DROPPING COLUMNS
def drop_columns(df, columns_to_drop:list):
    drop_columns = columns_to_drop  + [i for i in df.columns if i.__contains__("image")]
    df = df.drop(columns=drop_columns,
                errors="ignore")
    return df

# %% RENAMING COLUMNS

def renaming_columns(df, columns_to_rename: dict | None = None):

    cols = {}

    for n in df.columns:
        cols[n] = (n.replace(".", "_")
                    .replace("period", "set"))

    if columns_to_rename:
        cols.update(columns_to_rename)

    df = df.rename(columns=cols)

    return df

# %%

def save_db_silver(table_to_save,table_name):
    engine_silver = 'sqlite:///../../data/silver/db_silver.db'
    con_silver = sql.create_engine(engine_silver)
    table_to_save.to_sql(table_name, con=con_silver, if_exists='replace', index=False)
    print(f"Table {table_name} saved in db_silver.db! :)")

# %%
def json_column_expand(table,column:str):

    table[column] = table[column].apply(json.loads)

    exploded = (table.explode(column)
                    .reset_index(drop=True))
    
    stats = pd.json_normalize(exploded[column])

    result = pd.concat(
        [exploded.drop(columns=[column]).reset_index(drop=True), stats],
        axis=1
    )
    return result


