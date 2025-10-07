from dataclasses import dataclass
from typing import Optional, Dict, Tuple
import re

# --- Dataclasses for the structured result (unchanged) ---

@dataclass
class ThreadScheduler:
    breakdown_dma: int = 0
    breakdown_etc: int = 0
    breakdown_run: int = 0

@dataclass
class Logic:
    active_tasklets_0: int = 0
    active_tasklets_1: int = 0
    logic_cycle: int = 0
    num_instructions: int = 0

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


# --- Parsers ---

# Capture section, indices, metric, and value.
# Example line: "ThreadScheduler[0_0_9]_breakdown_run: 7020"
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
    Parse the whole simulator output into a dict keyed by the bracketed indices tuple.

    Returns:
        cores: dict where key is a tuple of indices (e.g., (0,0,9))
               and value is a SimStats populated from the lines for that core.
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

        # Populate fields (unknown metrics are ignored)
        if section == "ThreadScheduler":
            if metric == "breakdown_dma": stats.thread_scheduler.breakdown_dma = value
            elif metric == "breakdown_etc": stats.thread_scheduler.breakdown_etc = value
            elif metric == "breakdown_run": stats.thread_scheduler.breakdown_run = value

        elif section == "Logic":
            if metric == "active_tasklets_0": stats.logic.active_tasklets_0 = value
            elif metric == "active_tasklets_1": stats.logic.active_tasklets_1 = value
            elif metric == "logic_cycle": stats.logic.logic_cycle = value
            elif metric == "num_instructions": stats.logic.num_instructions = value

            # NOTE: Your dataclass only has active_tasklets_0 and _1.
            # Lines like active_tasklets_2..12 will be ignored by design.

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


# Backwards-compatible helper if you still want a single-core parse:
def parse_sim_stats(text: str, core: Tuple[int, ...] = (0, 0, 0)) -> SimStats:
    """
    Preserve the old API by selecting one core from the multi-core results.
    Defaults to (0,0,0). If the core isn't found, returns an empty SimStats.
    """
    cores = parse_sim_stats_multi(text)
    return cores.get(core, _new_stats())


# --- Example ---
if __name__ == "__main__":
    example = """\
ThreadScheduler[0_0_0]_breakdown_dma: 362
ThreadScheduler[0_0_0]_breakdown_etc: 2344
ThreadScheduler[0_0_0]_breakdown_run: 233
Logic[0_0_0]_active_tasklets_1: 2298
Logic[0_0_0]_logic_cycle: 2939
Logic[0_0_0]_num_instructions: 233
Logic[0_0_0]_active_tasklets_0: 641
CycleRule[0_0_0]_cycle_rule: 65
MemoryController[0_0_0]_memory_cycle: 17634
MemoryScheduler[0_0_0]_num_fcfs: 23
RowBuffer[0_0_0]_num_reads: 13
RowBuffer[0_0_0]_read_bytes: 104
RowBuffer[0_0_0]_num_activations: 3
RowBuffer[0_0_0]_num_precharges: 2
RowBuffer[0_0_0]_num_writes: 13
RowBuffer[0_0_0]_write_bytes: 104

ThreadScheduler[0_0_9]_breakdown_run: 6920
Logic[0_0_9]_num_instructions: 6920
RowBuffer[0_0_9]_num_reads: 1650
"""
    cores = parse_sim_stats_multi(example)
    print("cores parsed:", list(cores.keys()))
    print("(0,0,0):", cores[(0,0,0)])
    print("(0,0,9):", cores[(0,0,9)])
