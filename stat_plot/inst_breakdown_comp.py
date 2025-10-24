import pydantic
from simulation_parser import generate_stats
import experimented
from plot_inst_breakdown_comp import plot_instruction_breakdown
from extract_pd import generate_pandas_df


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
        if experiment_info.TEST_NAME not in ["BFS"]:
            continue
        summaries[
            f"{experiment_info.TEST_NAME} / {experiment_info.MAPPING} / {"Overhead only" if experiment_info.OVERHEAD_ONLY else "Overhead + Walker workload"}"
        ] = summary
    df1, df2 = generate_pandas_df(summaries)
    print(df1)
    print(df2)
    plot_instruction_breakdown(df2, title="Instruction Mix per Benchmark")
