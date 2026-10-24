import platform;
import from pathlib { Path }
import from uuid { UUID }

def collect_node_connections(
    current_node: NodeArchetype, visited_nodes: set, connections: set, edge_ids: set
) -> None;

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
