import pydantic
from simulation_parser import generate_stats, parse_sim_stats_multi, SimulationSummary
import experimented
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np


class SimulationConfig(pydantic.BaseModel):
    dpu_num: int
    max_dpu_thread_num: int
    MAPPING: str 
    TEST_NAME: str

def generate_pandas_df(benchmarks: dict[str, SimulationSummary]):
    """Generate a pandas dataframe from simulation results."""
    import pandas as pd

    # Get the list of all instruction types across all benchmarks
    all_instructions: set[str] = set(inst for bm in benchmarks.values() for inst in bm.instruction_counts.keys())
    regular_columns = [
        "benchmark",
        "total_dma",
        "total_etc",
        "total_run",
        "max_total_cycle",
    ] 
    instruction_columns = sorted(all_instructions)
    pd1 = pd.DataFrame(columns=regular_columns)
    pd2 = pd.DataFrame(columns=["benchmark"] + instruction_columns)

    for bm_name, bm_summary in benchmarks.items():
          # Make a list (row) in the same order as columns
          row = [
              f"{bm_name}",
              bm_summary.total_dma,
              bm_summary.total_etc,
              bm_summary.total_run,
              bm_summary.max_total_cycle,
          ]
          pd1.loc[len(pd1)] = row
          pd2.loc[len(pd2)] = [f"{bm_name}"] + [bm_summary.instruction_counts.get(inst, 0) for inst in instruction_columns]

    pd1.set_index("benchmark", inplace=True)
    pd2.set_index("benchmark", inplace=True)
    return pd1, pd2

if __name__ == "__main__":
    # Run standalone
    experiment = experimented.Experiment[SimulationConfig]()
    paths_and_data = experiment.list_experiments(experimented.find_store())
    summaries = {}
    for path, data in paths_and_data:
      experiment_info = SimulationConfig(**data.data)
      print(data)
      with open(path / "log.txt", "r") as f:
          output = f.read()
      summary = generate_stats(output)
      summaries[f"{experiment_info.TEST_NAME} / {experiment_info.MAPPING}"] = summary
    df1, df2 = generate_pandas_df(summaries)
    print(df1)
    print(df2)
    sns.set_theme(style="whitegrid")
    op_order = df2.sum(axis=0).sort_values(ascending=False).index
    fig, ax = plt.subplots(figsize=(10, 6))
    bottom = np.zeros(len(df2))
    for op in op_order:
        ax.bar(df2.index, df2[op].values, bottom=bottom, label=op)
        bottom += df2[op].values

    ax.set_title("Instruction Mix per Benchmark (Absolute)")
    ax.set_ylabel("Instruction count")
    plt.xticks(rotation=15, ha="right")
    ax.legend(ncol=4, bbox_to_anchor=(1, 1.02), loc="lower right", frameon=True)
    plt.tight_layout()
    # Save to file
    plt.savefig("instruction_mix_absolute.png")
