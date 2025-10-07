from dataclasses import dataclass, field
from typing import Dict, Tuple
import re

# --- Dataclasses (extended, but names preserved) ---

@dataclass
class ThreadScheduler:
    breakdown_dma: int = 0
    breakdown_etc: int = 0
    breakdown_run: int = 0

@dataclass
class Logic:
    # original fields (kept for compatibility)
    active_tasklets_0: int = 0
    active_tasklets_1: int = 0
    logic_cycle: int = 0
    num_instructions: int = 0

    # new fields / containers
    backpressure: int = 0
    # arbitrary active_tasklets_k captured here as k -> value
    active_tasklets: Dict[int, int] = field(default_factory=dict)
    # arbitrary inst_* captured here as suffix -> value (e.g., "ld", "add", "lsr_add")
    inst: Dict[str, int] = field(default_factory=dict)

@dataclass
class CycleRule:
    cycle_rule: int = 0

@dataclass
class MemoryController:
    memory_cycle: int = 0

@dataclass
class MemoryScheduler:
    num_fcfs: int = 0

@dataclass
class RowBuffer:
    num_reads: int = 0
    read_bytes: int = 0
    num_activations: int = 0
    num_precharges: int = 0
    num_writes: int = 0
    write_bytes: int = 0

@dataclass
class SimStats:
    thread_scheduler: ThreadScheduler
    logic: Logic
    cycle_rule: CycleRule
    memory_controller: MemoryController
    memory_scheduler: MemoryScheduler
    row_buffer: RowBuffer


# --- Parser ---

_LINE_RE = re.compile(
    r'^(?P<section>[A-Za-z]+)\[(?P<indices>[0-9_]+)\]_(?P<metric>[A-Za-z0-9_]+):\s*(?P<value>-?\d+)\s*$'
)

def _new_stats() -> SimStats:
    return SimStats(
        thread_scheduler=ThreadScheduler(),
        logic=Logic(),
        cycle_rule=CycleRule(),
        memory_controller=MemoryController(),
        memory_scheduler=MemoryScheduler(),
        row_buffer=RowBuffer(),
    )

def parse_sim_stats_multi(text: str) -> Dict[Tuple[int, ...], SimStats]:
    """
    Parse the whole simulator output into a dict keyed by the [i_j_k] tuple.
    Handles:
      - ThreadScheduler.* breakdown_*
      - Logic.* (logic_cycle, num_instructions, backpressure)
      - Logic.active_tasklets_<N>  -> Logic.active_tasklets[N]
        (also mirrors to active_tasklets_0/1 for N==0/1 for backward compat)
      - Logic.inst_*               -> Logic.inst["*"]
      - CycleRule.cycle_rule
      - MemoryController.memory_cycle
      - MemoryScheduler.num_fcfs
      - RowBuffer.* (reads/writes/activations/precharges/bytes)
    """
    cores: Dict[Tuple[int, ...], SimStats] = {}

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        m = _LINE_RE.match(line)
        if not m:
            continue

        section = m.group("section")
        idx_tuple = tuple(int(x) for x in m.group("indices").split("_"))
        metric = m.group("metric")
        value = int(m.group("value"))

        stats = cores.get(idx_tuple)
        if stats is None:
            stats = _new_stats()
            cores[idx_tuple] = stats

        if section == "ThreadScheduler":
            if metric == "breakdown_dma": stats.thread_scheduler.breakdown_dma = value
            elif metric == "breakdown_etc": stats.thread_scheduler.breakdown_etc = value
            elif metric == "breakdown_run": stats.thread_scheduler.breakdown_run = value

        elif section == "Logic":
            if metric == "logic_cycle": stats.logic.logic_cycle = value
            elif metric == "num_instructions": stats.logic.num_instructions = value
            elif metric == "backpressure": stats.logic.backpressure = value
            elif metric.startswith("active_tasklets_"):
                # active_tasklets_<N>
                try:
                    n = int(metric.split("_")[-1])
                except ValueError:
                    continue
                stats.logic.active_tasklets[n] = value
                if n == 0: stats.logic.active_tasklets_0 = value
                if n == 1: stats.logic.active_tasklets_1 = value
            elif metric.startswith("inst_"):
                # inst_*  -> store suffix (after "inst_")
                stats.logic.inst[metric[len("inst_"):]] = value
            # silently ignore other Logic.* lines

        elif section == "CycleRule":
            if metric == "cycle_rule": stats.cycle_rule.cycle_rule = value

        elif section == "MemoryController":
            if metric == "memory_cycle": stats.memory_controller.memory_cycle = value

        elif section == "MemoryScheduler":
            if metric == "num_fcfs": stats.memory_scheduler.num_fcfs = value

        elif section == "RowBuffer":
            if metric == "num_reads": stats.row_buffer.num_reads = value
            elif metric == "read_bytes": stats.row_buffer.read_bytes = value
            elif metric == "num_activations": stats.row_buffer.num_activations = value
            elif metric == "num_precharges": stats.row_buffer.num_precharges = value
            elif metric == "num_writes": stats.row_buffer.num_writes = value
            elif metric == "write_bytes": stats.row_buffer.write_bytes = value

    return cores


# Optional: keep your old single-core API (defaulting to (0,0,0))
def parse_sim_stats(text: str, core: Tuple[int, ...] = (0, 0, 0)) -> SimStats:
    return parse_sim_stats_multi(text).get(core, _new_stats())


# --- Example ---
if __name__ == "__main__":
    example = """\
ThreadScheduler[0_0_0]_breakdown_etc: 8897
ThreadScheduler[0_0_0]_breakdown_run: 7020
ThreadScheduler[0_0_0]_breakdown_dma: 7685
Logic[0_0_0]_inst_stop: 115
Logic[0_0_0]_active_tasklets_10: 885
Logic[0_0_0]_active_tasklets_11: 780
Logic[0_0_0]_logic_cycle: 24465
Logic[0_0_0]_num_instructions: 7020
Logic[0_0_0]_active_tasklets_7: 781
Logic[0_0_0]_active_tasklets_8: 790
Logic[0_0_0]_inst_resume: 55
Logic[0_0_0]_inst_ldma: 90
Logic[0_0_0]_inst_sd: 195
Logic[0_0_0]_inst_boot: 55
Logic[0_0_0]_active_tasklets_2: 2880
Logic[0_0_0]_inst_acquire: 3230
Logic[0_0_0]_inst_sw: 25
Logic[0_0_0]_inst_lbs: 115
Logic[0_0_0]_inst_lslx: 20
Logic[0_0_0]_inst_lsr_add: 40
Logic[0_0_0]_inst_add: 310
Logic[0_0_0]_backpressure: 863
Logic[0_0_0]_active_tasklets_6: 842
Logic[0_0_0]_inst_lsl: 20
Logic[0_0_0]_inst_addc: 30
Logic[0_0_0]_active_tasklets_1: 7186
Logic[0_0_0]_inst_or: 405
Logic[0_0_0]_inst_ld: 415
Logic[0_0_0]_active_tasklets_3: 2033
Logic[0_0_0]_active_tasklets_5: 866
Logic[0_0_0]_active_tasklets_0: 5346
Logic[0_0_0]_inst_call: 305
Logic[0_0_0]_active_tasklets_4: 904
Logic[0_0_0]_active_tasklets_9: 797
Logic[0_0_0]_inst_subc: 90
Logic[0_0_0]_active_tasklets_12: 375
Logic[0_0_0]_inst_sb: 225
Logic[0_0_0]_inst_lsl_add: 115
Logic[0_0_0]_inst_sdma: 20
Logic[0_0_0]_inst_sub: 595
Logic[0_0_0]_inst_release: 90
Logic[0_0_0]_inst_lbu: 185
Logic[0_0_0]_inst_lw: 140
Logic[0_0_0]_inst_and: 135
CycleRule[0_0_0]_cycle_rule: 1155
MemoryController[0_0_0]_memory_cycle: 146790
MemoryScheduler[0_0_0]_num_fcfs: 1641
RowBuffer[0_0_0]_num_reads: 1640
RowBuffer[0_0_0]_read_bytes: 13120
RowBuffer[0_0_0]_num_activations: 19
RowBuffer[0_0_0]_num_precharges: 14
RowBuffer[0_0_0]_num_writes: 20
RowBuffer[0_0_0]_write_bytes: 160
"""
    cores = parse_sim_stats_multi(example)
    core = cores[(0,0,0)]
    print("num_instructions:", core.logic.num_instructions)
    print("backpressure:", core.logic.backpressure)
    print("active_tasklets[10]:", core.logic.active_tasklets.get(10))
    print("inst['lsr_add']:", core.logic.inst.get("lsr_add"))
