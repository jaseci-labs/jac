"""In-process source-type adjacency matrix (AM layer) and GT topology helpers.

AM Structure:
    am_index[source_uuid_str][target_type_str] = [target_uuid_str, ...]

This is a process singleton. It is volatile — cleared on process restart.
It acts as an L1.5 cache over the GT topology tables (SQLite).

GT Structure:
    node_topology: (node_id, node_type, root_id)
    edge_topology: (edge_id, source_id, target_id, edge_type, target_type)

These live in the same SQLite file as the anchors table.

Only activates when SQLite persistence is present (jac start / jac scale).
Has zero effect for jac run (in-memory only).
"""

import from collections { defaultdict }
import from threading { Lock }
import from uuid { UUID }

glob __all__ = [
    'am_index',
    '_stats',
    '_get_lock',
    'reset_stats',
    'get_type_mro',
    'am_put',
    'am_invalidate',
    'am_query',
    'am_populate_from_gt',
    'am_clear',
    '_get_sqlite',
    '_gt_write_edge',
    '_gt_delete_edge',
    'gt_query_targets',
    'rebuild_gt',
    'rebuild_topology_index'
];

# ---------------------------------------------------------------------------
# Process-level singleton
# { source_id_str: { type_name: [target_id_str, ...] } }
# ---------------------------------------------------------------------------

glob am_index: dict[str, dict[str, list[str]]] = defaultdict(
    lambda: defaultdict(list)
);

# Per-source lock for thread-safe writes
glob _locks: dict[str, Lock] = {};
glob _locks_mu: Lock = Lock();

# Test-visible counters (zero overhead branch in production)
glob _stats: dict[str, int] = {
    'am_hits': 0,
    'am_misses': 0,
    'gt_hits': 0,
    'gt_misses': 0
};

# ---------------------------------------------------------------------------
# Lock helper
# ---------------------------------------------------------------------------

def _get_lock(source_id: str) -> Lock;

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

"""Reset all performance counters to zero. Used in tests."""
def reset_stats -> None;

# ---------------------------------------------------------------------------
# MRO helper
# ---------------------------------------------------------------------------

"""Return user-defined Jac type names from obj's MRO.

Walks type(obj).__mro__ and stops at any class whose module starts with
'jaclang' (internal runtime bases) or at 'object'.

Example:
    node Animal {}
    node Dog :Animal: {}

    get_type_mro(Dog()) -> ["Dog", "Animal"]

This enables parent-type queries at zero query-time cost:
    am_index[src]["Animal"] also contains Dog node IDs.
"""
def get_type_mro(obj: object) -> list[str];

# ---------------------------------------------------------------------------
# AM operations
# ---------------------------------------------------------------------------

"""Index a new edge in AM under all MRO types of the target archetype.

Called from build_edge() after the EdgeAnchor is created.
Thread-safe per source_id.
"""
def am_put(source_id: UUID, target_id: UUID, target_arch: object) -> None;

"""Remove all AM entries for a given source node.

Called from remove_edge() when any edge from source_id is removed.
Invalidates the entire source bucket — it will be repopulated lazily
from GT on the next traversal that misses AM.
"""
def am_invalidate(source_id: UUID) -> None;

"""Look up target IDs in AM for a given source and target type.

Returns:
    list of target UUID strings if the source bucket exists (may be empty),
    None if the source is not in AM (i.e. AM miss — must fall back to GT).
"""
def am_query(source_id: UUID, target_type: str) -> (list[str] | None);

"""Populate AM for a source node from GT query results.

gt_rows: list of (target_id_str, target_type_str) pairs.

Called after a GT query so subsequent traversals from the same source
hit AM instead of going to SQLite again.
"""
def am_populate_from_gt(source_id: UUID, gt_rows: list[tuple[str, str]]) -> None;

"""Wipe the entire AM index. Used in testing and rebuild scenarios."""
def am_clear -> None;

# ---------------------------------------------------------------------------
# GT helper: resolve SqliteMemory from any mem object
# ---------------------------------------------------------------------------

"""Return the SqliteMemory instance from mem, or None.

Handles bare SqliteMemory and TieredMemory whose .l3 is SqliteMemory.
Returns None for in-memory-only or jac-scale (MongoDB) configurations.
"""
def _get_sqlite(mem: object) -> (object | None);

# ---------------------------------------------------------------------------
# GT write/delete hooks
# ---------------------------------------------------------------------------

"""Write edge to GT (SQLite topology tables).

Called from build_edge() after source.edges.append(eanch).
Both source and target are fully populated NodeAnchor objects.
"""
def _gt_write_edge(
    mem: object, eanch: object, source: object, target: object
) -> None;

"""Delete edge row from GT topology tables.

Called from remove_edge() when an edge is removed.
node_topology rows are not touched here — a node persists after edges are removed.
"""
def _gt_delete_edge(mem: object, edge_id: UUID) -> None;

# ---------------------------------------------------------------------------
# GT query
# ---------------------------------------------------------------------------

"""Return list of target UUIDs from topology index.

Args:
    source_id:   UUID of the source node.
    edge_type:   None means any edge type (no edge filter).
    target_type: None means any node type (no node filter).

Returns:
    list of target UUID strings, or None if GT not available.
"""
def gt_query_targets(
    mem: object,
    source_id: UUID,
    edge_type: (str | None),
    target_type: (str | None)
) -> (list[str] | None);

# ---------------------------------------------------------------------------
# GT rebuild from anchor store
# ---------------------------------------------------------------------------

"""Reconstruct node_topology and edge_topology from the anchors table.

Safe to call on a live server — uses INSERT OR IGNORE / INSERT OR REPLACE
so duplicate inserts are idempotent. Existing correct rows are not overwritten.

Uses a two-pass approach:
  Pass 1: collect NodeAnchors -> build node_topology + node_id->type mapping.
  Pass 2: use EdgeAnchors + the mapping -> build edge_topology.
"""
def rebuild_gt(mem: object) -> None;

# ---------------------------------------------------------------------------
# Public rebuild API
# ---------------------------------------------------------------------------

"""Rebuild GT tables from anchor store, then warm AM from GT.

Safe to call on a running server. Returns a summary dict.
"""
def rebuild_topology_index(mem: object) -> dict[str, str];
