"""Topology Index for graph query optimization.

Stores a compact adjacency structure on root nodes so that edge-op chains
with type filters can be resolved without loading every node from the DB.

Two layered structures are kept in sync:
  * Canonical adj_list — `(src_lid, edge_type_id, tgt_lid)` triples; preserves
    multi-edge multiplicity, source of truth for encode/decode.
  * type-keyed lookup map — type-keyed dict
    `buckets[src_lid][col_key] = (in_lids, out_lids)` where `col_key` is
    `"n:<type_id>"` or `"e:<edge_type_id>"`. Gives O(1) per-type lookup and
    holds MRO fan-out (each target indexed under every ancestor type).

Encoding format (version 2):
  [1B version][2B num_types][2B num_nodes][4B num_edges]
  TypeTable:  for each type:
    [1B name_len][name_bytes...]
    [1B mro_len][mro_len × 2B ancestor_type_id]
  NodeTable:  for each node: [16B uuid][2B type_id][16B owner_root_uuid]
  AdjList:    for each edge: [2B src_lid][2B edge_type_id][2B tgt_lid]
"""

import struct;
import from typing { Any }
import from uuid { UUID }

glob SELF_ROOT: UUID = UUID(int=0),
     TOPO_VERSION: int = 2;

"""In-memory topology index with type-keyed adjacency matrix and MRO fan-out."""
obj TopologyIndex {
    has type_table: list[str] = [],
        type_to_id: dict[str, int] = {},
        type_mro_ids: list[list[int]] = [],
        node_table: list[tuple[UUID, int, UUID]] = [],
        node_to_lid: dict[UUID, int] = {},
        adj_list: list[tuple[int, int, int]] = [],
        buckets: dict[int, dict[str, tuple[set[int], set[int]]]] = {};

    def _ensure_type(type_name: str, mro_chain: (list[str] | None) = None) -> int;
    def add_node(
        node_id: UUID,
        type_name: str,
        mro_chain: (list[str] | None) = None,
        owner_root: (UUID | None) = None
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
