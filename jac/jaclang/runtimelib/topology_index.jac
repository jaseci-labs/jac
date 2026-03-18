"""Sparse Adjacency Matrix (SAM) for graph query optimization.

Replaces the binary-blob GLTI with a native Python dict structure.
Zero encode/decode overhead during normal operation — only serializes
when the anchor is pickled for persistence.

Structure:
  sam[source_uuid_str]["n:TypeName"] = [target_uuid_str, ...]
  sam[source_uuid_str]["e:EdgeType"] = [target_uuid_str, ...]

MRO fan-out: when a PostNode(BaseContent) is connected, SAM stores
target under both "n:PostNode" and "n:BaseContent", so parent-type
queries resolve at O(1) with no subtype enumeration.
"""

import from typing { Any }
import from uuid { UUID }

glob SELF_ROOT: UUID = UUID(int=0),
     TOPO_VERSION: int = 3;

"""Sparse Adjacency Matrix — O(1) type-keyed lookups per source node."""
obj TopologyIndex {
    # sam[source_id_str][column_key] = [target_id_str, ...]
    has sam: dict[str, dict[str, list[str]]] = {},
        node_owners: dict[str, UUID] = {};

    def add_edge(
        source_id: UUID, target_id: UUID,
        target_mro: list[str], edge_type: str
    ) -> None;

    def remove_edge(source_id: UUID, target_id: UUID) -> None;
    def remove_node(node_id: UUID) -> None;

    def query_targets(
        source_id: UUID, node_type: (str | None) = None,
        edge_type: (str | None) = None
    ) -> set[UUID];

    def resolve_chain(
        origin_ids: set[UUID], chain: list[tuple[(str | None), (str | None), int]]
    ) -> set[UUID];

    def get_cross_root_ids(node_ids: set[UUID]) -> dict[UUID, set[UUID]];
    def encode -> bytes;
    static def decode(data: bytes) -> TopologyIndex;
    def __len__ -> int;
    def __repr__ -> str;
}
