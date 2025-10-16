"""Simulation context generation for UPMEM codegen."""
from dataclasses import dataclass
from jaclang.runtimelib.jacpim_simulation_runtime.dpu_data_structs import MAX_DPU_THREAD_NUM
from jaclang.runtimelib.jacpim_simulation_runtime.simulation_parser import parse_sim_stats_multi
from pathlib import Path
from jaclang.runtimelib.jacpim_mapping_analysis.data_mapper import DPU_NUM
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
  
SIMULATOR_REPO_PATH = Path.home() / "uPIMulator" / "golang" / "uPIMulator"

def run_simulator(src: str) -> str:
    # Copy the src code to the simulator repo.
    path = Path(SIMULATOR_REPO_PATH) / "benchmark" / "GEN" / "dpu" / "task.c"
    with open(path, "w") as f:
        f.write(src)
    # Run the simulator and get the output.
    import subprocess
    # set a few environment variables
    import os
    os.environ["NUM_TASKLETS"] = str(MAX_DPU_THREAD_NUM)
    os.environ["NUM_DPUS"] = str(DPU_NUM)
    # Run bash run.sh under the simulator repo path.
    result = subprocess.run(
        ["bash", SIMULATOR_REPO_PATH / "run.sh" ],
        cwd=Path(SIMULATOR_REPO_PATH),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Simulator failed: {result.stderr}")

    # Get the output from path/to/simulator/bin/log.txt
    log_path = Path(SIMULATOR_REPO_PATH) / "bin" / "log.txt"
    with open(log_path, "r") as f:
        output = f.read()
    return output


@dataclass
class SimulationSummary:
    total_dma: int
    total_etc: int
    total_run: int
    max_total_cycle: int
    instruction_counts: dict[str, int]

@dataclass
class BenchmarkSummary:
    simulation_summary: dict[str, SimulationSummary]



def generate_stats(sim_output: str) -> SimulationSummary:
    """Generate aggregated stats from simulation results."""
    simulation_results = parse_sim_stats_multi(sim_output)
    total_dma = 0
    total_etc = 0
    total_run = 0

    for stats in simulation_results.values():
        total_dma += stats.thread_scheduler.breakdown_dma
        total_etc += stats.thread_scheduler.breakdown_etc
        total_run += stats.thread_scheduler.breakdown_run
    
    max_total_cycle = max(
        stats.thread_scheduler.breakdown_dma +
        stats.thread_scheduler.breakdown_etc +
        stats.thread_scheduler.breakdown_run
        for stats in simulation_results.values()
    )

    all_instructions: set[str] = set()
    for stats in simulation_results.values():
        all_instructions.update(stats.logic.inst.keys())
    # Log the aggregated stats
    return SimulationSummary(
        total_dma=total_dma,
        total_etc=total_etc,
        total_run=total_run,
        max_total_cycle=max_total_cycle,
        instruction_counts={inst: sum(
            stats.logic.inst.get(inst, 0) for stats in simulation_results.values()
        ) for inst in all_instructions}
    )

def generate_pandas_df(benchmarks: dict[str, BenchmarkSummary]):
    """Generate a pandas dataframe from simulation results."""
    import pandas as pd

    # Get the list of all instruction types across all benchmarks
    all_instructions: set[str] = set(inst for bm in benchmarks.values() for sim in bm.simulation_summary.values() for inst in sim.instruction_counts.keys())
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
        for sim_name, sim_summary in bm_summary.simulation_summary.items():
            # Make a list (row) in the same order as columns
            row = [
                f"{bm_name}_{sim_name}",
                sim_summary.total_dma,
                sim_summary.total_etc,
                sim_summary.total_run,
                sim_summary.max_total_cycle,
            ]
            pd1.loc[len(pd1)] = row
            pd2.loc[len(pd2)] = [f"{bm_name}_{sim_name}"] + [sim_summary.instruction_counts.get(inst, 0) for inst in instruction_columns]

    pd1.set_index("benchmark", inplace=True)
    pd2.set_index("benchmark", inplace=True)
    return pd1, pd2

if __name__ == "__main__":
    # Run standalone

    path = SIMULATOR_REPO_PATH / "bin" / "log.txt"
    with open(path, "r") as f:
        output = f.read()
    summary = generate_stats(output)
    df1, df2 = generate_pandas_df({"BinarySearch": BenchmarkSummary({"run1": summary}), "Fibonacci": BenchmarkSummary({"run1": summary})})
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

