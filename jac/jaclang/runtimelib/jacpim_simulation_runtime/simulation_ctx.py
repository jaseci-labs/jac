"""Simulation context generation for UPMEM codegen."""
from jaclang.runtimelib.jacpim_simulation_runtime.dpu_data_structs import MAX_DPU_THREAD_NUM
from .simulation_parser import parse_sim_stats_multi
from pathlib import Path
from jaclang.runtimelib.jacpim_mapping_analysis.data_mapper import DPU_NUM
from .simulation_parser import SimStats

  
SIMULATOR_REPO_PATH = Path.home() / "uPIMulator" / "golang" / "uPIMulator"

def run_simulator(src: str) -> dict[tuple[int, ...], SimStats]:
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
    return parse_sim_stats_multi(output)


def generate_stats(simulation_results: dict[tuple[int, ...], SimStats]) -> None:
    """Generate aggregated stats from simulation results."""
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
    
    print("Instruction counts:")
    for inst in sorted(all_instructions):
        print(inst)
    for inst in sorted(all_instructions):
        inst_count = sum(
            stats.logic.inst.get(inst, 0) for stats in simulation_results.values()
        )
        print(inst, inst_count)

    # Log the aggregated stats
    print(f"Total DMA cycles: {total_dma}")
    print(f"Total ETC cycles: {total_etc}")
    print(f"Total RUN cycles: {total_run}")
    print(f"Max total cycles: {max_total_cycle}")