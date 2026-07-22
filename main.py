# %%

from src.bronze import data_importing, treating_data_bronze, m_key
from src.silver import cleaning_formulas, treating_data_silver
from src.gold import gold
import sqlite3
import pandas as pd
from pathlib import Path
import pyarrow


def main():
    print("Running Bronze...")
    data_importing.main()
    treating_data_bronze.main()

    print("Running Silver...")
    treating_data_silver.main()


    print("Running Gold...")

    gold.main()
    
    print("Saving parquet!")

    db_path = r"/run/media/barbara/Barbara/Projetos/Independent_projects/VNL_Dashboard/data/gold/db_gold.db"
    file_out = Path(r"/run/media/barbara/Barbara/Projetos/Independent_projects/VNL_Dashboard/data/gold/parquet")
    file_out.mkdir(exist_ok=True)

    conn = sqlite3.connect(db_path)

    tables = pd.read_sql("SELECT name FROM sqlite_master WHERE type='table'", conn)

    for name in tables["name"]:
        df = pd.read_sql(f"SELECT * FROM {name}", conn)
        path = file_out / f"{name}.parquet"
        df.to_parquet(path, 
                      index=False, 
                      engine="pyarrow")
        print(f"exporting: {name}  ({len(df)} l/run/media/barbara/External)")

    conn.close()


    print("Refresh, updated!")

if __name__ == "__main__":
    main()


