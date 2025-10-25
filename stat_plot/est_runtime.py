import pydantic
from simulation_parser import generate_stats
import experimented
from plot_inst_breakdown_comp import plot_instruction_breakdown
from extract_pd import generate_pandas_df
import pandas as pd
from jaclang.runtimelib.jacpim_simulation_runtime.simulation_ctx import JacData
from jaclang.runtimelib.jacpim_perf_measure.cpu_run_ctx import TransferDirection

def get_pim_runtime(cycles: int) -> float:
    """Convert cycles to runtime in milliseconds."""
    CLOCK_FREQUENCY_HZ = (350*2**20)
    return (cycles / CLOCK_FREQUENCY_HZ)

def get_transfer_time(bytes_transferred: int) -> float:
    """Estimate transfer time in milliseconds."""
    TRANSFER_BANDWIDTH_BYTES_PER_SEC = 1.2*2**30 # 1.2 GB/s
    TRANSFER_LATENCY = 310/(10**9) # 310 ns
    return (bytes_transferred / TRANSFER_BANDWIDTH_BYTES_PER_SEC + TRANSFER_LATENCY)
    


class SimulationConfig(pydantic.BaseModel):
    dpu_num: int
    max_dpu_thread_num: int
    MAPPING: str
    TEST_NAME: str
    OVERHEAD_ONLY: bool

if __name__ == "__main__":
    experiment = experimented.Experiment[SimulationConfig]()
    paths_and_data = experiment.list_experiments(experimented.find_store())
    summaries = {}
    df = pd.DataFrame(columns=["benchmark", "PIM_RUN_TIME", "CPU->DPU_TRANSFERS", "DPU->CPU_TRANSFERS"])
    for path, data in paths_and_data:
        print(path)
        print(data)
        experiment_info = SimulationConfig(**data.data)
        with open(path / "log.txt", "r") as f:
            output = f.read()
        summary = generate_stats(output)
        if experiment_info.OVERHEAD_ONLY:
          continue
        with open(path / "jac_data.json", "r") as f:
            jac_data_json = f.read()
        jac_data = JacData.model_validate_json(jac_data_json)
        from_dpu_transfers = []
        for walker_transfers in jac_data.walker_jump_sizes:
            from_dpu_transfers += (
                [
                    transfer.size
                    for transfer in walker_transfers
                    if transfer.direction
                    == TransferDirection.FROM_DPU
                ]
            )
        to_dpu_transfers = []
        for walker_transfers in jac_data.walker_jump_sizes:
            to_dpu_transfers += (
                [
                    transfer.size
                    for transfer in walker_transfers
                    if transfer.direction == TransferDirection.TO_DPU
                ]
            )
        df = pd.concat(
            [
                df,
                pd.DataFrame(
                    [
                        {
                            "benchmark": experiment_info.TEST_NAME + f"_{experiment_info.MAPPING}",
                            "PIM_RUN_TIME": get_pim_runtime(summary.max_total_cycle),
                            "CPU->DPU_TRANSFERS": sum(get_transfer_time(size) for size in to_dpu_transfers),
                            "DPU->CPU_TRANSFERS": sum(get_transfer_time(size) for size in from_dpu_transfers),
                        }
                    ]
                )
            ],
            ignore_index=True,
        )
    df.set_index("benchmark", inplace=True)
    print(df)
    plot_instruction_breakdown(df, title="Estimated Runtime Breakdown per Benchmark", filename="est_runtime_breakdown.png")

            
        