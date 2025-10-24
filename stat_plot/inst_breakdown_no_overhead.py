import pydantic
from simulation_parser import generate_stats
import experimented
from plot_inst_breakdown_comp import plot_instruction_breakdown
from extract_pd import generate_pandas_df
import pandas as pd


class SimulationConfig(pydantic.BaseModel):
    dpu_num: int
    max_dpu_thread_num: int
    MAPPING: str
    TEST_NAME: str
    OVERHEAD_ONLY: bool


if __name__ == "__main__":
    # Run standalone
    experiment = experimented.Experiment[SimulationConfig]()
    paths_and_data = experiment.list_experiments(experimented.find_store())
    summaries = {}
    for path, data in paths_and_data:
        experiment_info = SimulationConfig(**data.data)
        with open(path / "log.txt", "r") as f:
            output = f.read()
        summary = generate_stats(output)
        summaries[
            f"{experiment_info.TEST_NAME} / {experiment_info.MAPPING} / {experiment_info.OVERHEAD_ONLY}"
        ] = summary
    df1, df2 = generate_pandas_df(summaries)
    df_diff = pd.DataFrame()
    for test_name in ["BFS"]:
        for mapping in ["JACPIM", "RANDOM"]:
            key1 = f"{test_name} / {mapping} / True"
            key2 = f"{test_name} / {mapping} / False"
            # Extract the two rows and subtract their instruction counts
            row1 = df2.loc[key1]
            row2 = df2.loc[key2]
            diff = row2 - row1
            print(diff)

            # Summarize all test, mapping combinations diff into a new dataframe
            df_diff = pd.concat([df_diff, diff.to_frame().T])
    df_diff.index = [
        f"{test_name} / {mapping} / No Overhead"
        for test_name in ["BFS"]
        for mapping in ["JACPIM", "RANDOM"]
    ]
    print("Instruction counts without overhead:")
    print(df_diff)
    plot_instruction_breakdown(
        df_diff,
        filename="instruction_mix_no_overhead.png",
        title="Instruction Mix per Benchmark (No Overhead)",
    )
