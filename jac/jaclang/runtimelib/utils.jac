"""Helper for construct."""
import from collections.abc { Callable }
import from pathlib { Path }
import from uuid { UUID }
import type from jaclang.jac0core.constructs { NodeArchetype }

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

"""Get project name from jac.toml if exists in same directory, None otherwise.

`target_path` is the entry-file path used to discover the project — when
omitted, falls back to `Jac.get_full_target_path()` (the bootstrap seed).
Callers that own a per-context identity (an ExecutionContext, a
JacTestClient) should pass it explicitly so the result is independent
of ambient seed state.
"""
def get_name(target_path: (str | None) = None) -> (str | None);

"""Get database path:
- Projects (jac.toml in same dir) → .jac/data/project-name.db
- Standalone files (no jac.toml) → .jac/data/filename.db

`target_path` is forwarded to `get_name` to derive the filename; see
`get_name` for back-compat behavior when omitted.
"""
def get_db_path(base_path: str, target_path: (str | None) = None) -> (str | None);
