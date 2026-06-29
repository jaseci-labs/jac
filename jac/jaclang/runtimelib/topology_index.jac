import struct;
import from uuid { UUID }

glob SELF_ROOT: UUID = UUID(int=0),
     TOPO_VERSION: int = 2;

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
        origin_ids: set[UUID],
        chain: list[tuple[(str | None), (str | None), int]],
        bail_on_intermediate_foreign: bool = False
    ) -> (set[UUID] | None);

    def resolve_chain_ordered(
        origin_ids: set[UUID],
        edge_type: (str | None),
        node_type: (str | None),
        direction: int,
        slc: slice
    ) -> list[UUID];

    def get_cross_root_ids(node_ids: set[UUID]) -> dict[UUID, set[UUID]];
    def encode -> bytes;
    static def decode(data: bytes) -> TopologyIndex;
    def __len__ -> int;
    def __repr__ -> str;
}
