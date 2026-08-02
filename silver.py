# %%
from src.silver import cleaning_formulas, treating_data_silver


def run_silver():
    print("Running Silver...")
    treating_data_silver.main()
    print("Silver done!")


if __name__ == "__main__":
    run_silver()