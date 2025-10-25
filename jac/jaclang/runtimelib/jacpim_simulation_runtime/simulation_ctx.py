"""Simulation context generation for UPMEM codegen."""

from dataclasses import dataclass
from datetime import datetime
import os
from jaclang.runtimelib.jacpim_simulation_runtime.dpu_data_structs import (
    MAX_DPU_THREAD_NUM,
)
from pathlib import Path
from jaclang.runtimelib.jacpim_mapping_analysis.data_mapper import DPU_NUM
from jaclang.runtimelib.jacpim_perf_measure.cpu_run_ctx import JacPIMCPURunCtx, TransferRecord
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import experimented
import pydantic


class JacData(pydantic.BaseModel):
    walker_jump_sizes: list[list[TransferRecord]]


class SimulationConfig(pydantic.BaseModel):
    dpu_num: int = DPU_NUM
    max_dpu_thread_num: int = MAX_DPU_THREAD_NUM
    MAPPING: str = os.environ.get("MAPPING")
    TEST_NAME: str = os.environ.get("TEST_NAME")
    OVERHEAD_ONLY: bool = os.environ.get("OVERHEAD_ONLY") == "1"


SIMULATOR_REPO_PATH = Path.home() / "uPIMulator" / "golang" / "uPIMulator"


def run_simulator(src: str) -> str:
    # Copy the src code to the simulator repo.
    path = Path(SIMULATOR_REPO_PATH) / "benchmark" / "GEN" / "dpu" / "task.c"
    with open(path, "w") as f:
        f.write(src)
    # Run the simulator and get the output.
    import subprocess

    os.environ["NUM_TASKLETS"] = str(MAX_DPU_THREAD_NUM)
    os.environ["NUM_DPUS"] = str(DPU_NUM)
    start_time = datetime.now()
    # Run bash run.sh under the simulator repo path.
    result = subprocess.run(
        ["bash", SIMULATOR_REPO_PATH / "run.sh"],
        cwd=Path(SIMULATOR_REPO_PATH),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Simulator failed: {result.stderr}")
    end_time = datetime.now()
    metadata = experimented.experiment_management.BaseExperimentMetadata(
        time_start=start_time, time_end=end_time
    )
    data = experimented.BaseExperiment[SimulationConfig](
        metadata=metadata, data=SimulationConfig()
    )
    experiment = experimented.Experiment[SimulationConfig]()
    with open(Path(SIMULATOR_REPO_PATH) / "bin" / "jac_data.json", "w") as f:
        walker_jump_sizes = JacPIMCPURunCtx.get_walker_jump_sizes()
        f.write(JacData(walker_jump_sizes=walker_jump_sizes).model_dump_json())

    experiment.add_experiment(data, Path(SIMULATOR_REPO_PATH) / "bin")

    # Get the output from path/to/simulator/bin/log.txt
    log_path = Path(SIMULATOR_REPO_PATH) / "bin" / "log.txt"
    with open(log_path, "r") as f:
        output = f.read()
    return output
