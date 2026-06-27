import ast as ast3;
import sys;
import from collections.abc { Callable, Iterator }
import from contextlib { contextmanager }
import from pathlib { Path }
import from types { UnionType }
import from uuid { UUID }
import jaclang.jac0core.unitree as uni;
import type from jaclang.jac0core.constructs { NodeArchetype }

@contextmanager
def sys_path_context(path: str) -> Iterator[None];

def collect_node_connections(
    current_node: NodeArchetype, visited_nodes: set, connections: set, edge_ids: set
) -> None;

def traverse_graph(
    nd: NodeArchetype,
    cur_depth: int,
    depth: int,
    edge_type: list[str],
    traverse: bool,
    connections: list,
    node_depths: dict[(NodeArchetype, int)],
    visited_nodes: list,
    queue: list[tuple[NodeArchetype, int]],
    bfs: bool,
    dfs: Callable,
    node_limit: int,
    edge_limit: int
) -> None;

def extract_type(nd: uni.UniNode) -> list[str];

def extract_params(
    body: uni.FuncCall
) -> tuple[
    dict[(str, uni.Expr)],
    list[tuple[(str, ast3.AST)]],
    list[tuple[(str, ast3.AST)]]
];

def is_instance(
    `obj: object, target: type | UnionType | tuple[((type | UnionType), ...)]
) -> bool;

def all_issubclass(
    classes: type | UnionType | tuple[((type | UnionType), ...)], target: type
) -> bool;

def storage_key(id: UUID) -> str {
    return f"anchor:{str(id)}";
}

def to_uuid(id: (UUID | str)) -> UUID {
    if isinstance(id, UUID) {
        return id;
    }
    return UUID(str(id));
}


def get_name(target_path: (str | None) = None) -> (str | None);


def get_db_path(base_path: str, target_path: (str | None) = None) -> (str | None);
