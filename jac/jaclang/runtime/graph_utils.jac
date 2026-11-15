import platform;
import from pathlib { Path }
import from uuid { UUID }

glob GRAPH_PAGE_MAX: int = 200,
     GRAPH_DIRS: dict[str, int] = {'out': 2, 'in': 1, 'both': 3};

def graph_type_named(base: type, key: str) -> (type | None);

def graph_node_view(nd: NodeArchetype) -> dict[str, any];

def graph_neighbors_view(
    nd: NodeArchetype,
    direction: str = 'out',
    node_type: (type | None) = None,
    edge_type: (type | None) = None,
    limit: int = 50,
    cursor: (str | None) = None
) -> dict[str, any];

def _graph_label(arch: Archetype) -> str;

def _graph_fields(arch: Archetype) -> dict[str, str];

def _graph_edge(
    e: (Anchor | None), origin: Anchor, other: Anchor, direction: int
) -> dict[str, any];

def _graph_cursor(text: (str | None)) -> (tuple[int, (UUID | None)] | None);

def _graph_cursor_text(key: (tuple[int, (UUID | None)] | None)) -> (str | None);

def traverse_graph(
    nd: NodeArchetype,
    cur_depth: int,
    depth: int,
    edge_type: list[str],
    traverse: bool,
    connections: list[tuple[NodeArchetype, NodeArchetype, EdgeArchetype]],
    node_depths: dict[(NodeArchetype, int)],
    visited_nodes: list[NodeArchetype],
    queue: list[tuple[NodeArchetype, int]],
    bfs: bool,
    dfs: Callable,
    node_limit: int,
    edge_limit: int
) -> None;

def storage_key(id: UUID) -> str;

def to_uuid(id: (UUID | str)) -> UUID;


def release_arch(raw: str) -> str;


def host_arch -> str;


def host_os -> str;


def triple_arch(triple: str) -> str;

def get_name(target_path: (str | None) = None) -> (str | None);

def get_db_path(base_path: str, target_path: (str | None) = None) -> (str | None);
