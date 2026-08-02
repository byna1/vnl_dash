# %%
from src.bronze import data_importing, treating_data_bronze, m_key


def run_bronze():
    print("Running Bronze...")
    data_importing.main()
    treating_data_bronze.main()
    print("Bronze done!")


if __name__ == "__main__":
    run_bronze()