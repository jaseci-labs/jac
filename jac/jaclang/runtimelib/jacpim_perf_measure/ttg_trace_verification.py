import networkx as nx
import pprint


def single_walker_all_jumps_included_in_ttg_counts(
    ttg: nx.MultiDiGraph, trace: list[int]
) -> tuple[int, int]:
    total_count = 0
    included_count = 0
    ttg_edges = set((u, v) for u, v in ttg.edges())
    for i in range(len(trace) - 1):
        jump = (trace[i], trace[i + 1])
        total_count += 1
        # Check if the jump exists in the TTG edges
        if jump in ttg_edges:
            included_count += 1
    return included_count, total_count

def single_walker_all_jumps_included_in_ttg(
    ttg: nx.MultiDiGraph, trace: list[int]
) -> bool:
    included_count, total_count = single_walker_all_jumps_included_in_ttg_counts(
        ttg, trace
    )
    return included_count == total_count


def all_walkers_all_jumps_included_in_ttg(
    ttg: nx.MultiDiGraph, traces: dict[int, list[int]]
) -> bool:
    return all(
        single_walker_all_jumps_included_in_ttg(ttg, trace) for trace in traces.values()
    )

def all_walkers_all_jumps_included_in_ttg_counts(
    ttg: nx.MultiDiGraph, traces: dict[int, list[int]]
) -> tuple[int, int]:
    total_included = 0
    total_jumps = 0
    for trace in traces.values():
        included_count, total_count = single_walker_all_jumps_included_in_ttg_counts(
            ttg, trace
        )
        total_included += included_count
        total_jumps += total_count
    print("DEBUG: all_walkers_all_jumps_included_in_ttg_counts")
    pp = pprint.PrettyPrinter(width=1200)
    pp.pprint(traces)
    print(f"DEBUG: Total included jumps: {total_included}, Total jumps: {total_jumps}. Percentage: {total_included / total_jumps if total_jumps > 0 else 0:.2%}")
    return total_included, total_jumps
