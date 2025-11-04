"""Generate Access pattern graph."""

from dataclasses import dataclass

import jaclang.compiler.unitree as uni
from jaclang.runtimelib.archetype import NodeArchetype
from jaclang.runtimelib.jacpim_static_analysis import (
    VisitInfo,
    static_ctx,
)
from jaclang.runtimelib.jacpim_static_analysis.info_extract import extract_name

import networkx as nx


@dataclass
class TemporalTraceTreeNode:
    """A node on the Temporal Trace Tree."""

    idx: int | None  # If it is None, it means this node represents the end of a path.
    conditional_next_nodes: list["TemporalTraceTreeNode"]
    parallel_next_nodes: list["TemporalTraceTreeNode"]


def print_ttt(node: TemporalTraceTreeNode) -> None:
    """Print temporal trace tree."""
    print("================")
    _print_ttt_simple(node)


def _print_ttt_simple(node: TemporalTraceTreeNode, level: int = 0) -> None:
    indent = "    " * level
    print(f"{indent}{node.idx}")
    for child in node.conditional_next_nodes + node.parallel_next_nodes:
        _print_ttt_simple(child, level + 1)


@dataclass
class WalkerState:
    """Store the walker state."""

    container: list[int]
    # path: list[int]
    ttt_node: TemporalTraceTreeNode

class NeighborFilterCtx:
    results: dict[tuple[int, VisitInfo], list[int]] = {}
    network: nx.MultiDiGraph | None = None

    @classmethod
    def setter(cls, network: nx.MultiDiGraph) -> None:
        cls.network = network
    
    @classmethod
    def get_network(cls) -> nx.MultiDiGraph:
        if cls.network is None:
            raise RuntimeError("Network is not set")
        return cls.network

    @classmethod
    def _filter_neighbors(cls,
        node_idx: int, visit: VisitInfo
    ) -> list[int]:
        network = cls.get_network()
        """Filter neighbors based on visit info and walker type."""
        filtered_neighbors = []

        # Get all neighbors
        for neighbor_idx in network.neighbors(node_idx):
            # Get edge data between current node and neighbor
            edge_datas = network.get_edge_data(node_idx, neighbor_idx)
            for edge_data in edge_datas.values():
                edge_arch = edge_data.get("archetype")
                if edge_arch is None:
                    raise RuntimeError("Archetype not found")
                edge_type = extract_name(edge_arch)

                if visit.edge_type is None or visit.edge_type == edge_type:
                    filtered_neighbors.append(neighbor_idx)

        return filtered_neighbors
    
    @classmethod
    def filter_neighbors(cls,
        node_idx: int, visit: VisitInfo
    ) -> list[int]:
        key = (node_idx, visit)
        if key not in cls.results:
            cls.results[key] = cls._filter_neighbors(node_idx, visit)
        return cls.results[key]

def exec_sync_visit_sequence(
    state: WalkerState, network: nx.MultiDiGraph, visits: list[VisitInfo]
) -> WalkerState:
    """Execute the visit sequence to get the access pattern."""
    new_container: list[int] = state.container.copy()
    # new_path: list[int] = state.path.copy()
    node = new_container.pop(0)
    visits = [visit for visit in visits if visit.async_edge is False]
    for visit in visits:
        filtered_neighbors = NeighborFilterCtx.filter_neighbors(node, visit)
        new_container.extend(
            filtered_neighbors
        )  # TODO: Insert one by one with regard to the visit index.
        # print(f"At node {node}, going to {filtered_neighbors} with visit {visit}")

    new_ttt_node = TemporalTraceTreeNode(
        idx=new_container[0] if len(new_container) > 0 else None,
        conditional_next_nodes=[],
        parallel_next_nodes=[],
    )

    return WalkerState(
        container=new_container,
        ttt_node=new_ttt_node,
    )


def get_new_walker_states(
    state: WalkerState, network: nx.MultiDiGraph, visit_sequences: list[list[VisitInfo]]
) -> list[WalkerState]:
    """Get new walker states based on the visit sequences."""
    new_states: list[WalkerState] = []
    NeighborFilterCtx.setter(network)
    for visit_sequence in visit_sequences:
        new_state = exec_sync_visit_sequence(state, network, visit_sequence)
        new_states.append(new_state)
        for visit_info in [v for v in visit_sequence if v.async_edge]:
            filtered_neighbors = NeighborFilterCtx.filter_neighbors(
                state.container[0], visit_info
            )
            for neighbor in filtered_neighbors:
                new_container = [neighbor]
                new_ttt_node = TemporalTraceTreeNode(
                    idx=new_container[0] if len(new_container) > 0 else None,
                    conditional_next_nodes=[],
                    parallel_next_nodes=[],
                )
                new_states.append(
                    WalkerState(
                        container=new_container,
                        ttt_node=new_ttt_node,
                    )
                )
    return new_states


def get_access_pattern_single_walker(
    start_node: NodeArchetype,
    network: nx.MultiDiGraph,
    walker_type: uni.Archetype,
    target_node_cnt: int = 100000,
) -> TemporalTraceTreeNode:
    """Get the access pattern for a single walker spawn."""
    start_idx = static_ctx.JacPIMStaticCtx.get_all_nodes().index(start_node)
    root_ttt_node = TemporalTraceTreeNode(
        idx=start_idx, conditional_next_nodes=[], parallel_next_nodes=[]
    )
    active_state_set: list[WalkerState] = [
        WalkerState(container=[start_idx], ttt_node=root_ttt_node)
    ]
    visit_sequences = static_ctx.JacPIMStaticCtx.get_walker_info(walker_type)
    # paths: list[list[int]] = []
    cnt = 0
    while len(active_state_set) > 0 and cnt < min(target_node_cnt, len(network.nodes)):
        cnt += 1
        state = active_state_set.pop(0)
        node = state.container[0]
        node_arch = network.nodes[node].get("archetype")
        if node_arch is None:
            raise RuntimeError("NodeArchetype Not found")
        node_type = extract_name(node_arch)
        new_state_set = get_new_walker_states(
            state, network, visit_sequences[node_type]
        )
        state.ttt_node.conditional_next_nodes = [
            new_state.ttt_node for new_state in new_state_set
        ]
        for new_state in new_state_set:
            if len(new_state.container) > 0 and new_state.container[0] is not None:
                active_state_set.append(new_state)

    return root_ttt_node


def get_paths_from_ttt(
    ttt_node: TemporalTraceTreeNode, current_path: list[int] | None = None
) -> list[list[int]]:
    """Extract all paths from the TTG."""
    if current_path is None:
        current_path = []
    if ttt_node.conditional_next_nodes == []:
        return [current_path.copy()]
    assert ttt_node.idx is not None
    current_path.append(ttt_node.idx)
    paths = []
    for next_node in ttt_node.conditional_next_nodes:
        paths.extend(get_paths_from_ttt(next_node, current_path))
    for next_node in ttt_node.parallel_next_nodes:
        paths.extend(get_paths_from_ttt(next_node, current_path))
    current_path.pop()
    return paths


@dataclass
class TTGEdgeAttribute:
    """Attributes of the Temporal Trace Graph Edges."""

    is_parallel_edge: bool
    timestamp: int


def get_ttg_from_ttt(input_ttt_nodes: list[TemporalTraceTreeNode]) -> nx.MultiDiGraph:
    """Generate the Temporal Trace Graph from ttt."""
    # print(get_paths_from_ttt(ttt_node))
    # print_ttt(ttt_node)
    graph = static_ctx.JacPIMStaticCtx.get_networkx().copy()
    graph.clear_edges()
    ttt_nodes: list[tuple[int, TemporalTraceTreeNode]] = [
        (0, ttt_node) for ttt_node in input_ttt_nodes
    ]
    while len(ttt_nodes) > 0:
        step, ttt_node = ttt_nodes.pop(0)
        if ttt_node.idx is None:
            raise RuntimeError("parent idx is None")
        for neighbor in ttt_node.conditional_next_nodes:
            if neighbor.idx is None:
                continue
            graph.add_edge(
                ttt_node.idx,
                neighbor.idx,
                ttg_attr=TTGEdgeAttribute(is_parallel_edge=False, timestamp=step),
            )
            # print(f"DEBUG: Edge from {ttt_node.idx} to {neighbor.idx}")
            ttt_nodes.append((step + 1, neighbor))
        for neighbor in ttt_node.parallel_next_nodes:
            if neighbor.idx is None:
                continue
            graph.add_edge(
                ttt_node.idx,
                neighbor.idx,
                ttg_attr=TTGEdgeAttribute(is_parallel_edge=True, timestamp=step),
            )
            # print(f"DEBUG: Parallel Edge from {ttt_node.idx} to {neighbor.idx}")
            ttt_nodes.append((step + 1, neighbor))
    return graph
