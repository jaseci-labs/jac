"""Topology Index for graph query optimization.

Stores a compact adjacency structure on root nodes so that edge-op chains
with type filters can be resolved without loading every node from the DB.

Encoding format (version 1):
  [1B version][2B num_types][2B num_nodes][4B num_edges]
  TypeTable:  for each type: [1B name_len][name_bytes...]
  NodeTable:  for each node: [16B uuid][2B type_id][16B owner_root_uuid (0=self)]
  AdjList:    for each edge: [2B source_local_id][2B edge_type_id][2B target_local_id]
"""

import struct;
import from typing { Any }
import from uuid { UUID }

glob SELF_ROOT: UUID = UUID(int=0),
     TOPO_VERSION: int = 1;

"""In-memory topology index decoded from a compact binary blob."""
obj TopologyIndex {
    has type_table: list[str] = [],
        type_to_id: dict[str, int] = {},
        node_table: list[tuple[UUID, int, UUID]] = [],
        node_to_lid: dict[UUID, int] = {},
        adj_list: list[tuple[int, int, int]] = [];

    def _ensure_type(type_name: str) -> int;
    def add_node(
        node_id: UUID, type_name: str, owner_root: (UUID | None) = None
    ) -> int;

    def remove_node(node_id: UUID) -> None;
    def add_edge(source_id: UUID, target_id: UUID, edge_type_name: str) -> None;
    def remove_edge(
        source_id: UUID, target_id: UUID, edge_type_name: (str | None) = None
    ) -> None;

    def resolve_chain(
        origin_ids: set[UUID], chain: list[tuple[(str | None), (str | None), int]]
    ) -> set[UUID];

    def get_cross_root_ids(node_ids: set[UUID]) -> dict[UUID, set[UUID]];
    def encode -> bytes;
    static def decode(data: bytes) -> TopologyIndex;
    def __len__ -> int;
    def __repr__ -> str;
}
