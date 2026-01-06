"""Helper for construct."""
import ast as ast3;
import sys;
import from collections.abc { Callable, Iterator }
import from contextlib { contextmanager }
import from types { UnionType }
import from typing { TYPE_CHECKING }
import from uuid { UUID }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.helpers {
    read_file_with_encoding as read_file_with_encoding
}

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { NodeArchetype }
    }
}

@contextmanager
def sys_path_context(path: str) -> Iterator[None];

def collect_node_connections(
    current_node: NodeArchetype, visited_nodes: set, connections: set, edge_ids: set
) -> None;

def traverse_graph(
    <>node: NodeArchetype,
    cur_depth: int,
    depth: int,
    edge_type: list[str],
    traverse: bool,
    connections: list,
    node_depths: dict[(NodeArchetype, int)],
    visited_nodes: list,
    queue: list,
    bfs: bool,
    dfs: Callable,
    node_limit: int,
    edge_limit: int
) -> None;

def extract_type(<>node: uni.UniNode) -> list[str];

def extract_params(
    body: uni.FuncCall
) -> tuple[
    dict[(str, uni.Expr)],
    list[tuple[(str, ast3.AST)]],
    list[tuple[(str, ast3.AST)]]
];

def is_instance(
    <>obj: object, target: type | UnionType | tuple[((type | UnionType), ...)]
) -> bool;

def all_issubclass(
    classes: type | UnionType | tuple[((type | UnionType), ...)], target: type
) -> bool;

"""Generate a storage key for an anchor ID."""
def storage_key(id: UUID) -> str {
    return f"anchor:{str(id)}";
}

"""Convert string or UUID to UUID."""
def to_uuid(id: (UUID | str)) -> UUID {
    if isinstance(id, UUID) {
        return id;
    }
    return UUID(str(id));
}
