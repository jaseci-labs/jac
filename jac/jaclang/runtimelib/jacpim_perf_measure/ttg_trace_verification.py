from .cpu_run_ctx import JacPIMCPURunCtx
import networkx as nx

def single_walker_all_jumps_included_in_ttg(
    ttg: nx.MultiDiGraph, trace: list[int]
) -> bool:
    ttg_edges = set((u, v) for u, v in ttg.edges())
    for i in range(len(trace) - 1):
        jump = (trace[i], trace[i + 1])
        # Check if the jump exists in the TTG edges
        if jump not in ttg_edges:
            return False
        
    return True

def all_walkers_all_jumps_included_in_ttg(
    ttg: nx.MultiDiGraph, traces: dict[int, list[int]]
) -> bool:
    return all(
        single_walker_all_jumps_included_in_ttg(ttg, trace)
        for trace in traces.values()
    )