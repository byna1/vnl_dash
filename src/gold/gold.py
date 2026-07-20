# %% 

import pandas as pd
import sqlalchemy as sql
import os 

con_silver = sql.create_engine("sqlite:///data/silver/db_silver.db")
con_gold = sql.create_engine("sqlite:///data/gold/db_gold.db")

file_path = "src/gold/"

def saving_queries(sql_path: str, con_silver, con_gold):

    with open(sql_path, "r", encoding="utf-8") as q:
        query = q.read()

    df = pd.read_sql(query, con=con_silver)

    nome_tabela = (os.path
                    .basename(sql_path)
                    .removesuffix(".sql")
                    .removeprefix("R_")) 
    df.to_sql(nome_tabela, 
              con=con_gold, 
              if_exists="replace", 
              index=False)

    print(f"Table {nome_tabela} saved ({len(df)} rows)")


def main():

    for file_name in os.listdir(file_path):

        if file_name.endswith(".sql") and file_name.startswith("R_"):
        
            saving_queries(os.path
                             .join(file_path, file_name),
                             con_silver, 
                             con_gold)


#  %%
if __name__ == "__main__":
    main()
