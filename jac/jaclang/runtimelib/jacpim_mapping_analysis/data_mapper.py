"""Graph Partitioning binding."""

import random

from jaclang.runtimelib.archetype import NodeArchetype
from jaclang.runtimelib.jacpim_static_analysis.info_extract import (
    get_node_info_from_node_arch,
)
from jaclang.runtimelib.jacpim_static_analysis.static_ctx import JacPIMStaticCtx

import networkx as nx
import os

DPU_SIZE_LIMIT = 1024
DPU_NUM = 50
RESERVED_SIZE = 128
MAX_PARTITION_SIZE = DPU_SIZE_LIMIT - RESERVED_SIZE


class NodeDistribution:
    """Node to DPU mapping management."""

    def __init__(self) -> None:
        """Initialize to an empty partitioning."""
        self.node_to_partition: dict[int, int] = {}
        self.partition_availability: list[int] = [0] * DPU_NUM

    def add_node(self, node: int, partition: int, node_size: int) -> None:
        """Add a single node to a partition."""
        self.node_to_partition[node] = partition
        self.partition_availability[partition] += node_size
        assert self.partition_availability[partition] <= MAX_PARTITION_SIZE

    def node_assigned(self, node: int) -> bool:
        """Check whether a node has been assigned to a DPU."""
        return node in self.node_to_partition

    def available_partitions(self, node_size: int) -> list[int]:
        """Get a list of available partition IDs."""
        return [
            i
            for i in range(DPU_NUM)
            if self.partition_availability[i] + node_size <= MAX_PARTITION_SIZE
        ]

    def get_dpu_data_amount(self) -> list[int]:
        """Get the data amount of each DPU core."""
        return self.partition_availability

    def get_partition(self) -> dict[int, int]:
        """Get the partitioning."""
        return self.node_to_partition


class RoundRobinPartitioner:
    """Round Robin JacPIM Partitioner."""

    def _remove_duplicates(self, lst: list[tuple[int, int]]) -> list[tuple[int, int]]:
        """Remove duplicates while preserving order."""
        seen = set()
        result = []
        for depth, item in lst:
            if item not in seen:
                seen.add(item)
                result.append((depth, item))
        return result

    def _dfs_round_robin_on_node(
        self,
        node_distribution: NodeDistribution,
        ttg: nx.MultiDiGraph,
        start_node_idx: int,
        offset: int,
    ) -> None:
        """Run a basic dfs to get the partitioning in DFS order."""
        stack: list[tuple[int, int]] = [(0, start_node_idx)]
        visited: set[int] = set()
        print(f"Starting DFS from node {start_node_idx}")
        while len(stack) > 0:
            depth, node = stack.pop(0)
            next_nodes = ttg.edges(node, keys=True, data=True)
            next_nodes = [
                (depth + 1, next_node[1])
                for next_node in next_nodes
                if not (next_node[3].get("ttg_attr").is_parallel_edge)
                if (next_node[3].get("ttg_attr").timestamp == depth)
                if next_node[1] not in visited
                if next_node[1] != node
                if next_node[1] not in stack
            ]
            next_nodes = self._remove_duplicates(next_nodes)
            
            next_nodes_idx = [n[1] for n in next_nodes]
            # print(next_nodes)
            visited |= set(next_nodes_idx)
            stack += next_nodes
            node_size = get_node_info_from_node_arch(
                JacPIMStaticCtx.get_all_nodes()[node]
            ).node_size_bytes
            if node_distribution.node_assigned(node):
                continue
            partitions = node_distribution.available_partitions(node_size)
            if len(partitions) == 0:
                raise RuntimeError("No available partitions.")
            partition = partitions[offset % len(partitions)]
            node_distribution.add_node(node, partition, node_size)
            print(f"Visited {len(visited)} nodes.")

    def __init__(self, ttg: nx.MultiDiGraph, start_nodes: list[NodeArchetype]) -> None:
        """Get the partitioning done."""
        self.node_distribution = NodeDistribution()
        for idx, start_node in enumerate(start_nodes):
            start_node_idx = JacPIMStaticCtx.get_all_nodes().index(start_node)
            self._dfs_round_robin_on_node(
                self.node_distribution, ttg, start_node_idx, offset=idx
            )
        for node_idx in range(len(JacPIMStaticCtx.get_all_nodes())):
            if not self.node_distribution.node_assigned(node_idx):
                node_size = get_node_info_from_node_arch(
                    JacPIMStaticCtx.get_all_nodes()[node_idx]
                ).node_size_bytes
                partitions = self.node_distribution.available_partitions(node_size)
                if len(partitions) == 0:
                    raise RuntimeError("No available partitions.")
                if os.environ.get("MAPPING_STRATEGY") == "FIRST_FIT":
                    partition = min(partitions)
                else:
                    partition = random.choice(partitions)
                self.node_distribution.add_node(node_idx, partition, node_size)

    def get_data_partitioning(self) -> dict[int, int]:
        """Retrieve the partitioning."""
        return self.node_distribution.get_partition()

class JacPIMStepFFPartitioner:
    """JacPIM Step-based First-Fit Partitioner."""

    def __init__(self, ttg: nx.MultiDiGraph, start_nodes: list[NodeArchetype]) -> None:
        """Get the partitioning done."""
        self.node_distribution = NodeDistribution()
        for idx, start_node in enumerate(start_nodes):
            start_node_idx = JacPIMStaticCtx.get_all_nodes().index(start_node)
            node_size = get_node_info_from_node_arch(
                JacPIMStaticCtx.get_all_nodes()[start_node_idx]
            ).node_size_bytes
            self.node_distribution.add_node(start_node_idx, idx % DPU_NUM, node_size)
        
        # Get the max depth of the TTG
        max_depth = 0
        for u, v, data in ttg.edges(data=True):
            ttg_attr = data.get("ttg_attr")
            if ttg_attr and ttg_attr.timestamp > max_depth:
                max_depth = ttg_attr.timestamp
        
        for depth in range(max_depth + 1):
            # Get all edges at this depth
            edges_at_depth = [
                (u, v) for u, v, data in ttg.edges(data=True)
                if data.get("ttg_attr") and data.get("ttg_attr").timestamp == depth
            ]
            for u, v in edges_at_depth:
                # Assert the the source node has been assigned
                assert self.node_distribution.node_assigned(u), f"Node {u} not assigned yet."
                # If the target node is already assigned, skip
                if self.node_distribution.node_assigned(v):
                    continue
                node_size = get_node_info_from_node_arch(
                    JacPIMStaticCtx.get_all_nodes()[v]
                ).node_size_bytes
                available_partitions = self.node_distribution.available_partitions(node_size)
                # Try to assign to the same partition as the source node
                preferred_partition = self.node_distribution.node_to_partition[u]
                if preferred_partition in available_partitions:
                    self.node_distribution.add_node(v, preferred_partition, node_size)
                elif len(available_partitions) > 0:
                    # Assign to the first available partition
                    self.node_distribution.add_node(v, available_partitions[0], node_size)
                else:
                    raise RuntimeError("No available partitions.")
        print(f"Assigned nodes up to depth {max_depth}. Assigned nodes: {len(self.node_distribution.node_to_partition)}")
        for node_idx in range(len(JacPIMStaticCtx.get_all_nodes())):
            if not self.node_distribution.node_assigned(node_idx):
                node_size = get_node_info_from_node_arch(
                    JacPIMStaticCtx.get_all_nodes()[node_idx]
                ).node_size_bytes
                partitions = self.node_distribution.available_partitions(node_size)
                if len(partitions) == 0:
                    raise RuntimeError("No available partitions.")
                if os.environ.get("MAPPING_STRATEGY") == "FIRST_FIT":
                    partition = min(partitions)
                else:
                    partition = random.choice(partitions)
                self.node_distribution.add_node(node_idx, partition, node_size)


    def get_data_partitioning(self) -> dict[int, int]:
        """Retrieve the partitioning."""
        return self.node_distribution.get_partition()


class RandomPartitioner:
    """Random JacPIM Partitioner (baseline)."""

    def __init__(self, ttg: nx.MultiDiGraph, _: list[NodeArchetype]) -> None:
        """Get the partitioning done."""
        self.node_distribution = NodeDistribution()
        # self._dfs_round_robin_on_node(self.node_distribution, ttg, start_node_idx, 0)
        for node in ttg.nodes():
            if self.node_distribution.node_assigned(node):
                continue
            node_size = get_node_info_from_node_arch(
                JacPIMStaticCtx.get_all_nodes()[node]
            ).node_size_bytes
            partition = random.choice(
                self.node_distribution.available_partitions(node_size)
            )
            self.node_distribution.add_node(node, partition, node_size)

    def get_data_partitioning(self) -> dict[int, int]:
        """Retrieve the partitioning."""
        return self.node_distribution.get_partition()
