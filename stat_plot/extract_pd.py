import pandas as pd
from simulation_parser import SimulationSummary


def generate_pandas_df(
    benchmarks: dict[str, SimulationSummary]
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Generate a pandas dataframe from simulation results."""

    # Get the list of all instruction types across all benchmarks
    all_instructions: set[str] = set(
        inst for bm in benchmarks.values() for inst in bm.instruction_counts.keys()
    )
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
        pd2.loc[len(pd2)] = [f"{bm_name}"] + [
            bm_summary.instruction_counts.get(inst, 0) for inst in instruction_columns
        ]

    pd1.set_index("benchmark", inplace=True)
    pd2.set_index("benchmark", inplace=True)
    return pd1, pd2
