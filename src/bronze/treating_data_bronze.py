# %% 

import pandas as pd
import sqlalchemy as sql
import json
import os
# %% 

print("Creating conection with db...")

engine = "sqlite:///../../data/bronze/db_bronze.db"

con = sql.create_engine(engine)

print("Loading tables into database... ")

def make_text(x):
    if isinstance(x, (list, dict)):
        return json.dumps(x, ensure_ascii=False)
    return x

def load_tables(table_name):
    with open(f"../../data/bronze/{table_name}",encoding="utf-8") as m:
        data = json.load(m)

    df = pd.json_normalize(data)
    df = df.map(make_text)

    for_table_name = table_name.replace(".json", "")
    df.to_sql(for_table_name, con=con, if_exists="replace", index=False)

def main ():

    files = os.listdir("../../data/bronze/")

    for n in files:
        if not n.endswith(".json"):
            continue
        load_tables(n)
        print(f"Table {n} imported!")

    print(f"COMPLETED!")

main()


# %% 

if __name__ == main():
    main()
