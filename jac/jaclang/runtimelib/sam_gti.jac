"""Sparse Adjacency Matrix (SAM) and Graph Topology Index (GTI) helpers.

SAM Structure:
    sam_index[source_uuid_str][column_key] = [target_uuid_str, ...]

    Column keys are prefixed to avoid node/edge type name collisions:
        "n:TypeName"  — node-type column (MRO fan-out: PostNode → also "n:BaseContent")
        "e:TypeName"  — edge-type column (direct type only, no MRO)

    Example:
        sam_index["user_1"] = {
            "n:PostNode":    ["p1", "p2"],
            "n:BaseContent": ["p1", "p2", "c1", "c2"],  ← MRO superset
            "e:FollowEdge":  ["u2", "u3"],
        }

    This is a process singleton. It is volatile — cleared on process restart.
    It acts as an L1.5 cache over the GTI topology tables (SQLite).

GTI Structure:
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
    'sam_index',
    '_stats',
    '_get_lock',
    'reset_stats',
    'get_type_mro',
    'sam_put',
    'sam_invalidate',
    'sam_query',
    'sam_populate_from_gti',
    'sam_clear',
    '_get_sqlite',
    '_gti_write_edge',
    '_gti_delete_edge',
    'gti_query_targets',
    'rebuild_gti',
    'rebuild_topology_index'
];

# ---------------------------------------------------------------------------
# Process-level singleton
# { source_id_str: { column_key: [target_id_str, ...] } }
# column_key is prefixed: "n:NodeType" or "e:EdgeType"
# ---------------------------------------------------------------------------

glob sam_index: dict[str, dict[str, list[str]]] = defaultdict(
    lambda: defaultdict(list)
);

# Per-source lock for thread-safe writes
glob _locks: dict[str, Lock] = {};
glob _locks_mu: Lock = Lock();

# Test-visible counters (zero overhead branch in production)
glob _stats: dict[str, int] = {
    'sam_hits': 0,
    'sam_misses': 0,
    'gti_hits': 0,
    'gti_misses': 0
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
    sam_index[src]["n:Animal"] also contains Dog node IDs.
"""
def get_type_mro(obj: object) -> list[str];

# ---------------------------------------------------------------------------
# SAM operations
# ---------------------------------------------------------------------------

"""Index a new edge in SAM under all MRO types of the target and the edge type.

Writes:
    "n:TargetType" (and all MRO ancestors) → target_id
    "e:EdgeType"                            → target_id

Called from build_edge() after the EdgeAnchor is created.
Thread-safe per source_id.
"""
def sam_put(
    source_id: UUID,
    target_id: UUID,
    target_arch: object,
    edge_arch: object
) -> None;

"""Remove all SAM entries for a given source node.

Called from remove_edge() when any edge from source_id is removed.
Invalidates the entire source bucket — it will be repopulated lazily
from GTI on the next traversal that misses SAM.
"""
def sam_invalidate(source_id: UUID) -> None;

"""Look up target IDs in SAM for a given source and column key.

Args:
    key: prefixed column key, e.g. "n:PostNode" or "e:FollowEdge".

Returns:
    list of target UUID strings if the column key has been populated for this
    source (the list may be empty when indexed but no matching targets exist),
    None if the source bucket is absent OR the column key has never been
    written (both are SAM misses — caller must fall back to GTI).
"""
def sam_query(source_id: UUID, key: str) -> (list[str] | None);

"""Populate SAM for a source node from GTI query results.

gt_rows: list of (target_id_str, column_key) pairs.
         column_key must already be prefixed: "n:X" or "e:X".

Called after a GTI query so subsequent traversals from the same source
hit SAM instead of going to SQLite again.
"""
def sam_populate_from_gti(source_id: UUID, gt_rows: list[tuple[str, str]]) -> None;

"""Wipe the entire SAM index. Used in testing and rebuild scenarios."""
def sam_clear -> None;

# ---------------------------------------------------------------------------
# GTI helper: resolve SqliteMemory from any mem object
# ---------------------------------------------------------------------------

"""Return the SqliteMemory instance from mem, or None.

Handles bare SqliteMemory and TieredMemory whose .l3 is SqliteMemory.
Returns None for in-memory-only or jac-scale (MongoDB) configurations.
"""
def _get_sqlite(mem: object) -> (object | None);

# ---------------------------------------------------------------------------
# GTI write/delete hooks
# ---------------------------------------------------------------------------

"""Write edge to GTI (SQLite topology tables).

Called from build_edge() after source.edges.append(eanch).
Both source and target are fully populated NodeAnchor objects.
"""
def _gti_write_edge(
    mem: object, eanch: object, source: object, target: object
) -> None;

"""Delete edge row from GTI topology tables.

Called from remove_edge() when an edge is removed.
node_topology rows are not touched here — a node persists after edges are removed.
"""
def _gti_delete_edge(mem: object, edge_id: UUID) -> None;

"""Delete all node_topology rows for a given node.

Called from destroy() when a NodeAnchor is deleted. Prevents stale ghost rows
from accumulating in node_topology for nodes that no longer exist.
"""
def _gti_delete_node(mem: object, node_id: UUID) -> None;

# ---------------------------------------------------------------------------
# GTI query
# ---------------------------------------------------------------------------

"""Return list of target UUIDs from topology index.

Args:
    source_id:   UUID of the source node.
    edge_type:   None means any edge type (no edge filter).
    target_type: None means any node type (no node filter).

Returns:
    list of target UUID strings, or None if GTI not available.
"""
def gti_query_targets(
    mem: object,
    source_id: UUID,
    edge_type: (str | None),
    target_type: (str | None)
) -> (list[str] | None);

# ---------------------------------------------------------------------------
# GTI rebuild from anchor store
# ---------------------------------------------------------------------------

"""Reconstruct node_topology and edge_topology from the anchors table.

Safe to call on a live server — uses INSERT OR IGNORE / INSERT OR REPLACE
so duplicate inserts are idempotent. Existing correct rows are not overwritten.

Uses a two-pass approach:
  Pass 1: collect NodeAnchors -> build node_topology + node_id->type mapping.
  Pass 2: use EdgeAnchors + the mapping -> build edge_topology.
"""
def rebuild_gti(mem: object) -> None;

# ---------------------------------------------------------------------------
# Public rebuild API
# ---------------------------------------------------------------------------

"""Rebuild GTI tables from anchor store, then warm SAM from GTI.

Safe to call on a running server. Returns a summary dict.
"""
def rebuild_topology_index(mem: object) -> dict[str, str];
