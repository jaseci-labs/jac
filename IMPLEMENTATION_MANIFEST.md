# Implementation Manifest: Graph Topology Index (GT + AM) for Jaseci

## Overview

This manifest specifies exactly what to build, where in the codebase to build it, and in
what order. It covers both the **GT layer** (persistent topology index in SQLite) and the
**AM layer** (in-process source-type adjacency matrix as a warm cache over GT).

**Scope:** This implementation targets the non-scale path only — `SqliteMemory` as the
anchor store. The jac-scale path (MongoDB + Redis/FalkorDB) is deferred to future work
and is described separately at the end of this document.

The goal is to eliminate the N+1 anchor-fetch pattern that occurs during filtered walker
traversals. The implementation is purely additive to the existing memory hierarchy — no
existing behaviour changes unless a filter is present and degree exceeds a configurable
threshold.

---

## Background: The Problem in the Current Code

### The bottleneck

`edges_to_nodes()` in [jac/jaclang/jac0core/runtime.jac:300](jac/jaclang/jac0core/runtime.jac#L300):

```
for nd in origin:
    nanch = nd.__jac__
    for anchor in nanch.edges:          # ← iterates ALL edge stubs
        anchor.source                   # ← triggers populate() → SQLite read per stub
        anchor.target                   # ← same
        destination.edge_filter(...)    # ← type check after loading
        destination.node_filter(...)    # ← type check after loading
```

`NodeAnchor.edges` is a list of `EdgeAnchor` stubs — each stub only holds an `id`. The
moment `anchor.source`, `anchor.target`, or `anchor.archetype` is accessed, `__getattr__`
fires ([archetype.impl.jac:150](jac/jaclang/jac0core/impl/archetype.impl.jac#L150)):

```
impl Anchor.__getattr__(self, name):
    if not self.is_populated():
        self.populate()          # → ctx.mem.get(self.id) → L1 → L2 → SQLite
```

For a node with degree 500 and selectivity 10% (only 50 nodes match the type filter), the
current path loads 500 anchors and discards 450. The AM path loads 50.

### The write path

`build_edge()` in [runtime.jac:1611](jac/jaclang/jac0core/runtime.jac#L1611) is where
edges are created. At the moment the edge is built, both `source` and `target` are fully
populated in L1. This is the only point where the target's type is known without an extra
fetch — making it the correct write hook for the AM.

`detach()` and `remove_edge()` in [runtime.jac:337](jac/jaclang/jac0core/runtime.jac#L337)
are where edges are deleted. These are the correct invalidation hooks for AM entries.

### The storage layer

`SqliteMemory` in [runtimelib/impl/memory.impl.jac](jac/jaclang/runtimelib/impl/memory.impl.jac)
stores anchors in a single table:

```sql
CREATE TABLE anchors (
    id   TEXT PRIMARY KEY,
    data BLOB NOT NULL          -- pickled Anchor object
);
```

There are no topology tables. The entire edge list is embedded inside the pickled
`NodeAnchor.edges` blob. Querying "which nodes of type T are connected to node X"
requires loading and unpickling X's anchor, iterating its edge stubs, loading each stub,
and filtering in Python.

---

## Architecture: Three-Tier Index Resolution

```
Walker traversal: [here-->](?:TargetNode)
        |
        v
[1] Is nanch in L1 (__mem__)?
        | YES → pointer-chase in memory (current behaviour, no change)
        | NO  → cache miss on nanch
                |
                v
[2] Does destination have a type/edge filter AND len(nanch.edges) > threshold?
        | NO  → fetch-and-filter as usual (current behaviour)
        | YES →
                |
                v
[3] Check AM (in-process dict, zero I/O):
        am_index[nanch.id]["TargetNode"]
        | HIT → get matching target UUIDs → bulk-fetch from ctx.mem
        | MISS →
                |
                v
[4] Query GT (SQLite topology tables, microseconds):
        SELECT target_id FROM edge_topology
        WHERE source_id = ? AND target_type = ?
        | → populate AM entry for this source
        | → get matching target UUIDs → bulk-fetch from ctx.mem
```

**L1 (`__mem__`):** per-request Python dict, cleared on context close.
**AM:** process-level singleton Python dict, survives across requests, lost on restart.
**GT:** two topology tables in the same SQLite file, survives restarts, reconstructible.
**Anchor store:** existing `anchors` table, unchanged. Never modified by this feature.

---

## Part 1: GT Layer — Persistent Topology Tables (SQLite)

### 1.1 Schema

Two new tables added to the same SQLite file managed by `SqliteMemory`. The file is the
existing `.jac/data/anchor_store.db` (or whatever path `SqliteMemory` is configured with)
— no new database file is created.

```sql
CREATE TABLE IF NOT EXISTS node_topology (
    node_id   TEXT NOT NULL,
    node_type TEXT NOT NULL,
    root_id   TEXT,
    PRIMARY KEY (node_id, node_type)
);
CREATE INDEX IF NOT EXISTS idx_nt_type   ON node_topology (node_type);
CREATE INDEX IF NOT EXISTS idx_nt_root   ON node_topology (root_id, node_type);

CREATE TABLE IF NOT EXISTS edge_topology (
    edge_id     TEXT PRIMARY KEY,
    source_id   TEXT NOT NULL,
    target_id   TEXT NOT NULL,
    edge_type   TEXT NOT NULL,
    target_type TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_et_source ON edge_topology (source_id, edge_type, target_type);
CREATE INDEX IF NOT EXISTS idx_et_target ON edge_topology (target_id, edge_type);
```

`target_type` is denormalised onto `edge_topology` intentionally. The most common query
is "edges from source X of edge type E pointing to nodes of type T" — this is a single
index scan with no join.

`root_id` on `node_topology` enables per-root spatial partitioning (aligns with Jaseci's
access control model where each user has a root node).

### 1.2 Where to add the schema

**File:** [jac/jaclang/runtimelib/impl/memory.impl.jac](jac/jaclang/runtimelib/impl/memory.impl.jac)

**Function:** `SqliteMemory._ensure_connection` (line ~164)

After the existing `CREATE TABLE IF NOT EXISTS anchors` block, add the two topology tables
and their indexes. Because `_ensure_connection` is called lazily on first write, the
topology tables are created at the same moment as the anchor table — same connection,
same file.

```
# existing anchor table creation
self.__conn__.execute("CREATE TABLE IF NOT EXISTS anchors ...")

# new: topology tables
self.__conn__.execute("""
    CREATE TABLE IF NOT EXISTS node_topology (
        node_id   TEXT NOT NULL,
        node_type TEXT NOT NULL,
        root_id   TEXT,
        PRIMARY KEY (node_id, node_type)
    )
""")
self.__conn__.execute("""
    CREATE INDEX IF NOT EXISTS idx_nt_type ON node_topology (node_type)
""")
self.__conn__.execute("""
    CREATE TABLE IF NOT EXISTS edge_topology (
        edge_id     TEXT PRIMARY KEY,
        source_id   TEXT NOT NULL,
        target_id   TEXT NOT NULL,
        edge_type   TEXT NOT NULL,
        target_type TEXT NOT NULL
    )
""")
self.__conn__.execute("""
    CREATE INDEX IF NOT EXISTS idx_et_source
        ON edge_topology (source_id, edge_type, target_type)
""")
self.__conn__.commit()
```

No migration is needed for existing databases — `IF NOT EXISTS` handles both fresh and
pre-existing databases.

### 1.3 GT write hook — `build_edge()`

**File:** [jac/jaclang/jac0core/runtime.jac](jac/jaclang/jac0core/runtime.jac#L1611)

**Function:** the inner `builder(source, target)` closure inside `build_edge()`.

At the point `builder` is called, `source` and `target` are fully populated `NodeAnchor`
objects in L1. The edge anchor `eanch` has just been created.

After `source.edges.append(eanch)` (and the undirected `target.edges.append(eanch)` if
applicable), add a topology write:

```python
# After existing: source.edges.append(eanch)
_gt_write_edge(
    mem=JacRuntimeInterface.get_context().mem,
    eanch=eanch,
    source=source,
    target=target
)
```

`_gt_write_edge` is a standalone function (not a method) defined in the new
`am_index` module (see Part 2):

```python
def _gt_write_edge(mem, eanch, source, target):
    """Write edge to GT (SQLite topology tables) if mem has a SqliteMemory l3."""
    sqlite = _get_sqlite(mem)
    if sqlite is None or sqlite.__conn__ is None:
        return
    edge_type  = type(eanch.archetype).__name__
    target_type = type(target.archetype).__name__
    root_id = str(target.root) if target.root else None
    # node_topology: upsert target node under all its MRO types
    for t in get_type_mro(target.archetype):
        sqlite.__conn__.execute(
            "INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id) "
            "VALUES (?, ?, ?)",
            (str(target.id), t, root_id)
        )
    # edge_topology: one row per edge
    sqlite.__conn__.execute(
        "INSERT OR REPLACE INTO edge_topology "
        "(edge_id, source_id, target_id, edge_type, target_type) "
        "VALUES (?, ?, ?, ?, ?)",
        (str(eanch.id), str(source.id), str(target.id), edge_type, target_type)
    )
    # Note: commit is deferred to the normal SqliteMemory.sync() call.
    # Do NOT commit here — avoid per-edge fsync overhead.
```

The commit happens when `SqliteMemory.sync()` is called at context close. The topology
writes share the same transaction as anchor writes — atomicity for free.

### 1.4 GT delete hook — `remove_edge()`

**File:** [jac/jaclang/jac0core/runtime.jac](jac/jaclang/jac0core/runtime.jac#L337)

**Function:** `JacRuntimeInterface.remove_edge(nd, edge)`

After the existing `nd.edges.pop(idx)`, add:

```python
_gt_delete_edge(
    mem=JacRuntimeInterface.get_context().mem,
    edge_id=edge.id
)
```

```python
def _gt_delete_edge(mem, edge_id):
    sqlite = _get_sqlite(mem)
    if sqlite is None or sqlite.__conn__ is None:
        return
    sqlite.__conn__.execute(
        "DELETE FROM edge_topology WHERE edge_id = ?", (str(edge_id),)
    )
    # node_topology rows are NOT deleted here — a node continues to exist
    # even after all edges are removed. node_topology rows are cleaned up
    # only when the node itself is destroyed (see destroy() hook).
```

### 1.5 GT query function

Used by `edges_to_nodes()` when AM misses:

```python
def gt_query_targets(mem, source_id, edge_type, target_type):
    """Return list of target UUIDs from topology index.

    Args:
        edge_type:   None means any edge type (no edge filter)
        target_type: None means any node type (no node filter)
    Returns:
        list of UUID strings, or None if GT not available
    """
    sqlite = _get_sqlite(mem)
    if sqlite is None:
        return None
    if sqlite.__conn__ is None and not os.path.exists(sqlite.path):
        return None
    if sqlite.__conn__ is None:
        sqlite._ensure_connection()

    params = [str(source_id)]
    where  = ["source_id = ?"]
    if edge_type:
        where.append("edge_type = ?")
        params.append(edge_type)
    if target_type:
        where.append("target_type = ?")
        params.append(target_type)

    sql = (
        "SELECT target_id FROM edge_topology WHERE "
        + " AND ".join(where)
    )
    cur = sqlite.__conn__.execute(sql, params)
    return [row[0] for row in cur.fetchall()]
```

### 1.6 GT rebuild utility

Called at startup or after a crash to reconstruct topology tables from the anchor store.

```python
def rebuild_gt(mem):
    """Reconstruct node_topology and edge_topology from the anchors table.

    Safe to call on a live server — uses INSERT OR IGNORE / INSERT OR REPLACE
    so duplicate inserts are idempotent. Existing correct rows are not overwritten.
    """
    sqlite = _get_sqlite(mem)
    if sqlite is None:
        return
    sqlite._ensure_connection()
    conn = sqlite.__conn__

    from pickle import loads
    from jaclang.jac0core.archetype import NodeAnchor

    cur = conn.execute("SELECT data FROM anchors")
    for (blob,) in cur:
        try:
            anchor = loads(blob)
        except Exception:
            continue
        if not isinstance(anchor, NodeAnchor) or not anchor.is_populated():
            continue
        root_id = str(anchor.root) if anchor.root else None
        for t in get_type_mro(anchor.archetype):
            conn.execute(
                "INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id) "
                "VALUES (?, ?, ?)",
                (str(anchor.id), t, root_id)
            )
        for eanch in anchor.edges:
            if not eanch.is_populated():
                continue
            edge_type   = type(eanch.archetype).__name__
            target_type = (
                type(eanch.target.archetype).__name__
                if eanch.target and eanch.target.is_populated() else None
            )
            if target_type is None:
                continue
            conn.execute(
                "INSERT OR REPLACE INTO edge_topology "
                "(edge_id, source_id, target_id, edge_type, target_type) "
                "VALUES (?, ?, ?, ?, ?)",
                (str(eanch.id), str(anchor.id), str(eanch.target.id),
                 edge_type, target_type)
            )
    conn.commit()
```

---

## Part 2: AM Layer — In-Process Source-Type Adjacency Matrix

### 2.1 New module: `am_index`

**File to create:** `jac/jaclang/runtimelib/am_index.py`

This module is a process-level singleton. Its contents persist across walker calls and
HTTP requests for the lifetime of the server process.

```python
"""
In-process source-type adjacency matrix (AM layer).

Structure:
    am_index[source_uuid_str][target_type_str] = [target_uuid_str, ...]

This is a process singleton. It is volatile — cleared on process restart.
It acts as an L1.5 cache over the GT topology tables (SQLite).
"""

from __future__ import annotations
import os
import threading
from collections import defaultdict
from uuid import UUID

# The index: { source_id_str: { type_name: [target_id_str, ...] } }
am_index: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))

# Per-source lock for thread-safe writes
_locks: dict[str, threading.Lock] = {}
_locks_mu = threading.Lock()


def _get_lock(source_id: str) -> threading.Lock:
    with _locks_mu:
        if source_id not in _locks:
            _locks[source_id] = threading.Lock()
        return _locks[source_id]


def get_type_mro(obj) -> list[str]:
    """Return user-defined Jac type names from obj's MRO.

    Walks type(obj).__mro__ and stops at any class whose module starts with
    'jaclang' (internal runtime bases) or at 'object'.

    Example:
        node Animal {}
        node Dog :Animal: {}

        get_type_mro(Dog()) → ["Dog", "Animal"]

    This enables parent-type queries at zero query-time cost:
        am_index[src]["Animal"] also contains Dog node IDs.
    """
    result = []
    for cls in type(obj).__mro__:
        mod = getattr(cls, "__module__", "") or ""
        if mod.startswith("jaclang") or cls.__name__ == "object":
            break
        result.append(cls.__name__)
    return result


def am_put(source_id: UUID, target_id: UUID, target_arch) -> None:
    """Index a new edge in AM under all MRO types of the target archetype.

    Called from build_edge() after the EdgeAnchor is created.
    Thread-safe per source_id.
    """
    src_str = str(source_id)
    tgt_str = str(target_id)
    lock = _get_lock(src_str)
    with lock:
        bucket = am_index[src_str]
        for type_name in get_type_mro(target_arch):
            if tgt_str not in bucket[type_name]:
                bucket[type_name].append(tgt_str)


def am_invalidate(source_id: UUID) -> None:
    """Remove all AM entries for a given source node.

    Called from remove_edge() when any edge from source_id is removed.
    Invalidates the entire source bucket — it will be repopulated lazily
    from GT on the next traversal that misses AM.
    """
    src_str = str(source_id)
    lock = _get_lock(src_str)
    with lock:
        am_index.pop(src_str, None)


def am_query(source_id: UUID, target_type: str) -> list[str] | None:
    """Look up target IDs in AM for a given source and target type.

    Returns:
        list of target UUID strings if the source bucket exists (may be empty),
        None if the source is not in AM (i.e. AM miss — must fall back to GT).
    """
    src_str = str(source_id)
    bucket = am_index.get(src_str)
    if bucket is None:
        return None   # AM miss
    return bucket.get(target_type, [])


def am_populate_from_gt(source_id: UUID, gt_rows: list[tuple[str, str]]) -> None:
    """Populate AM for a source node from GT query results.

    gt_rows: list of (target_id_str, target_type_str) pairs.

    Called after a GT query so subsequent traversals from the same source
    hit AM instead of going to SQLite again.
    """
    src_str = str(source_id)
    lock = _get_lock(src_str)
    with lock:
        bucket = am_index[src_str]
        for (tgt_id, tgt_type) in gt_rows:
            if tgt_id not in bucket[tgt_type]:
                bucket[tgt_type].append(tgt_id)


def am_clear() -> None:
    """Wipe the entire AM index. Used in testing and rebuild scenarios."""
    with _locks_mu:
        am_index.clear()
        _locks.clear()
```

### 2.2 Helper: get the SqliteMemory from a mem object

Used by all GT functions. Handles both a bare `SqliteMemory` and a `TieredMemory` whose
`.l3` is a `SqliteMemory`. Returns `None` for any other configuration (e.g. a
`TieredMemory` whose `.l3` is `None` because no persistence path was set), in which case
the GT path is silently skipped and the existing edge-list loop runs as normal.

```python
def _get_sqlite(mem):
    from jaclang.runtimelib.memory import SqliteMemory
    if isinstance(mem, SqliteMemory):
        return mem
    l3 = getattr(mem, "l3", None)
    if isinstance(l3, SqliteMemory):
        return l3
    return None  # jac-scale (MongoDB) or in-memory only — GT not available in this scope
```

When `_get_sqlite` returns `None`, every GT function (`_gt_write_edge`,
`gt_query_targets`, `_gt_delete_edge`) is a no-op. AM still operates normally — it just
never gets a GT fallback on cold misses, so those misses fall through to the existing
edge-list loop.

---

## Part 3: Modified `edges_to_nodes()`

**File:** [jac/jaclang/jac0core/runtime.jac](jac/jaclang/jac0core/runtime.jac#L300)

This is the highest-impact change. The existing function:

```
static def edges_to_nodes(
    origin: list[NodeArchetype], destination: ObjectSpatialDestination
) -> list[NodeArchetype] {
    nodes: OrderedDict = OrderedDict()
    for nd in origin {
        nanch = nd.__jac__
        for anchor in nanch.edges {          # N+1 loading starts here
            ...filter and collect...
        }
    }
    return list(nodes.values())
}
```

### 3.1 The decision heuristic

The AM/GT path is consulted only when ALL of the following are true:

1. `nanch` is populated in memory (we have `nanch.edges`, so degree is known)
2. `destination` has a non-trivial node type filter (`destination.node_filter` is not
   the pass-through `GenericNode` check) — this needs an `ObjectSpatialDestination`
   predicate to inspect. The simplest approach: check if `destination.node_types` (or
   equivalent) is non-empty/non-wildcard.
3. `len(nanch.edges) > DEGREE_THRESHOLD` (default: 10 for SQLite, configurable)

If the heuristic is false, fall through to the existing loop unchanged.

### 3.2 What `ObjectSpatialDestination` exposes

Before modifying `edges_to_nodes`, verify what filter information is accessible on the
`destination` object. From [runtime.jac](jac/jaclang/jac0core/runtime.jac), the call is:

```
destination.edge_filter(anchor.archetype)   # edge type check
destination.node_filter(target.archetype)   # target node type check
```

These are predicate callables. To extract the *type name* for an AM lookup (rather than
calling the predicate after loading), we need access to the raw type constraint. Check
`ObjectSpatialDestination` in [archetype.jac](jac/jaclang/jac0core/archetype.jac) for
attributes like `.filter_type`, `.node_types`, or similar. The AM lookup requires a
type name string, not a loaded archetype object.

**If `ObjectSpatialDestination` exposes the filter type as a class or name**, use it
directly. If it only exposes a predicate, a short-term approach is to pass a sentinel
node stub to `node_filter()` and inspect which types it accepts — but this is fragile.
The cleaner fix is to add a `node_type_name: str | None` attribute to
`ObjectSpatialDestination` populated when the filter is compiled (this is a small, targeted
change in the filter compilation path).

### 3.3 Modified `edges_to_nodes` pseudocode

```
static def edges_to_nodes(origin, destination) -> list[NodeArchetype] {
    import from jaclang.runtimelib.am_index {
        am_query, am_populate_from_gt, am_put
    }
    import from jaclang.runtimelib.am_index { _get_sqlite, gt_query_targets }

    DEGREE_THRESHOLD = 10
    nodes = OrderedDict()
    ctx   = JacRuntimeInterface.get_context()

    for nd in origin {
        nanch = nd.__jac__

        # --- AM/GT fast path ---
        target_type_name = destination.node_type_name   # None if wildcard
        edge_type_name   = destination.edge_type_name   # None if any
        use_index = (
            nanch.is_populated()
            and target_type_name is not None
            and len(nanch.edges) > DEGREE_THRESHOLD
        )

        if use_index {
            target_ids = am_query(nanch.id, target_type_name)

            if target_ids is None {
                # AM miss → query GT
                gt_ids = gt_query_targets(
                    ctx.mem, nanch.id, edge_type_name, target_type_name
                )
                if gt_ids is not None {
                    # Populate AM so next traversal from this node hits AM
                    am_populate_from_gt(
                        nanch.id,
                        [(tid, target_type_name) for tid in gt_ids]
                    )
                    target_ids = gt_ids
                }
            }

            if target_ids is not None {
                # Bulk-fetch matching anchors and apply access control
                from uuid import UUID
                for id_str in target_ids {
                    uid = UUID(id_str)
                    target = ctx.mem.get(uid)
                    if (
                        target
                        and target.archetype
                        and JacRuntimeInterface.check_read_access(target)
                    ) {
                        nodes[target] = target.archetype
                    }
                }
                continue   # skip the edge-list loop for this node
            }
        }

        # --- Existing edge-list loop (fallback) ---
        for anchor in nanch.edges {
            if (
                (source := anchor.source)
                and (target := anchor.target)
                and destination.edge_filter(anchor.archetype)
                and source.archetype
                and target.archetype
            ) {
                if (
                    (destination.direction in [EdgeDir.OUT, EdgeDir.ANY])
                    and (nanch == source)
                    and destination.node_filter(target.archetype)
                    and JacRuntimeInterface.check_read_access(target)
                ) {
                    nodes[target] = target.archetype
                }
                if (
                    (destination.direction in [EdgeDir.IN, EdgeDir.ANY])
                    and (nanch == target)
                    and destination.node_filter(source.archetype)
                    and JacRuntimeInterface.check_read_access(source)
                ) {
                    nodes[source] = source.archetype
                }
            }
        }
    }

    return list(nodes.values())
}
```

The `continue` after the index path skips the edge-list loop entirely for that node.
The fallback loop is completely unchanged — no existing behaviour is altered when the
heuristic is false.

---

## Part 4: `ObjectSpatialDestination` — Expose Filter Type Names

**File:** [jac/jaclang/jac0core/archetype.jac](jac/jaclang/jac0core/archetype.jac)
(and its impl)

Add two optional attributes to `ObjectSpatialDestination`:

```
has node_type_name: (str | None) = None   # populated if query has (?:TypeName)
has edge_type_name: (str | None) = None   # populated if query has -[EdgeType]->
```

These are populated at the point where `ObjectSpatialDestination` is constructed from
the Jac filter expression — in the pass that compiles `[here-->](?:TypeName)` into an
`ObjectSpatialPath`. This is the only change needed to the filter compilation path.

If `node_type_name` is `None`, the filter is a wildcard and the AM path is skipped
(wildcard traversals benefit less from type-keyed indexing).

---

## Part 5: `build_edge()` Write Hook

**File:** [jac/jaclang/jac0core/runtime.jac](jac/jaclang/jac0core/runtime.jac#L1617)

The inner `builder` closure is the only write site for edges. After the existing
`source.edges.append(eanch)` line:

```python
# Existing
source.edges.append(eanch)
if is_undirected:
    target.edges.append(eanch)

# New: update AM and GT
from jaclang.runtimelib.am_index import am_put, _gt_write_edge
am_put(source.id, target.id, target.archetype)
if is_undirected:
    am_put(target.id, source.id, source.archetype)
_gt_write_edge(
    mem=JacRuntimeInterface.get_context().mem,
    eanch=eanch, source=source, target=target
)
```

`am_put` is thread-safe per source (see Part 2). `_gt_write_edge` defers commit to the
normal `sync()` cycle — no per-edge fsync.

---

## Part 6: `remove_edge()` Invalidation Hook

**File:** [jac/jaclang/jac0core/runtime.jac](jac/jaclang/jac0core/runtime.jac#L337)

After the existing `nd.edges.pop(idx)`:

```python
# Existing
nd.edges.pop(idx)

# New: invalidate AM for this source node
from jaclang.runtimelib.am_index import am_invalidate, _gt_delete_edge
am_invalidate(nd.id)
_gt_delete_edge(
    mem=JacRuntimeInterface.get_context().mem,
    edge_id=edge.id
)
```

`am_invalidate` drops the entire source bucket. It will be lazily repopulated from GT on
the next traversal. This is simpler and safer than attempting a targeted removal from the
AM bucket (which would require knowing the target type of the removed edge without loading
the edge stub).

---

## Part 7: `rebuild_topology_index()` Public API

**File:** `jac/jaclang/runtimelib/am_index.py` (append to the module)

A public function that operators or startup code can call to warm both GT and AM:

```python
def rebuild_topology_index(mem) -> dict:
    """Rebuild GT tables from anchor store, then warm AM from GT.

    Safe to call on a running server. Returns a summary dict.
    """
    am_clear()
    rebuild_gt(mem)      # repopulate SQLite topology tables

    # Warm AM from the now-correct GT tables
    sqlite = _get_sqlite(mem)
    if sqlite is None or sqlite.__conn__ is None:
        return {"gt": "rebuilt", "am": "skipped (no sqlite)"}

    cur = sqlite.__conn__.execute(
        "SELECT source_id, target_id, target_type FROM edge_topology"
    )
    count = 0
    for (src, tgt, ttype) in cur.fetchall():
        bucket = am_index[src]
        if tgt not in bucket[ttype]:
            bucket[ttype].append(tgt)
        count += 1

    return {"gt": "rebuilt", "am": f"warmed ({count} edges)"}
```

---

## Implementation Order

Build and test in this sequence. Each step is independently testable.

### Step 1 — `am_index.py` module (no runtime changes yet)

Create `jac/jaclang/runtimelib/am_index.py` with `am_put`, `am_query`,
`am_invalidate`, `am_populate_from_gt`, `am_clear`, `get_type_mro`.

Write unit tests: put entries, query with MRO, invalidate, thread-safety smoke test.

No integration yet. No behaviour changes.

### Step 2 — GT schema in `SqliteMemory._ensure_connection`

Add the two topology tables and indexes to
[runtimelib/impl/memory.impl.jac](jac/jaclang/runtimelib/impl/memory.impl.jac).

Run existing memory tests to confirm no regression. Inspect new SQLite files with
`sqlite3` to confirm tables are created.

### Step 3 — GT write/delete hooks in `build_edge` and `remove_edge`

Add `_gt_write_edge` and `_gt_delete_edge` calls at the two sites in
[runtime.jac](jac/jaclang/jac0core/runtime.jac).

Add AM write (`am_put`) calls in the same block.

Write an integration test: create a graph, inspect `edge_topology` rows directly,
remove an edge, confirm GT row is deleted, confirm AM entry for source is gone.

### Step 4 — `ObjectSpatialDestination` type name attributes

Add `node_type_name` and `edge_type_name` to `ObjectSpatialDestination` in
[archetype.jac](jac/jaclang/jac0core/archetype.jac) and populate them in the filter
compilation pass.

Verify that `(?:TargetNode)` queries set `node_type_name = "TargetNode"` and wildcard
queries set it to `None`.

### Step 5 — Modified `edges_to_nodes`

Integrate the AM/GT fast path into `edges_to_nodes` with the heuristic guard
(degree > threshold, non-None `node_type_name`).

Run the full existing test suite. The fast path must produce identical results to the
existing loop — same nodes, same ordering (OrderedDict preserves insertion order;
bulk-fetch ordering must match the GT query result ordering, or ordering must be
reconciled).

### Step 6 — `rebuild_topology_index()` and startup hook

Add the rebuild utility and wire it to a configurable startup option
(`JAC_REBUILD_TOPOLOGY_ON_START=1` or equivalent).

Test with a pre-existing SQLite database that has no topology tables: run rebuild, confirm
tables are populated, run a walker traversal and confirm AM/GT path is taken.

### Step 7 — Benchmarks and threshold calibration

Run the existing benchmark app (`benchmarking/graph-query-bench/`) against the real
integrated path (not the simulation). Calibrate `DEGREE_THRESHOLD`. Confirm the
crossover point matches the cost model from DISCUSSION.md (~10–15 edges for SQLite).

---

## Configuration

All tunable parameters exposed via environment variables or `jac.toml`:

| Variable | Default | Meaning |
|---|---|---|
| `JAC_INDEX_DEGREE_THRESHOLD` | `10` | Min node degree to use AM/GT path |
| `JAC_INDEX_ENABLED` | `true` | Master switch for the entire index layer |
| `JAC_REBUILD_TOPOLOGY_ON_START` | `false` | Run `rebuild_gt()` at server startup |
| `JAC_AM_MAX_SOURCES` | `0` (unlimited) | LRU eviction limit for AM source entries |

`JAC_INDEX_ENABLED=false` must produce identical behaviour to the current code. This
allows A/B testing and emergency rollback without code changes.

---

## Test Methodology

The core problem with testing this optimisation is that walker output is opaque to the
path taken — a traversal returning 50 nodes looks identical whether 50 or 500 anchors
were loaded from SQLite. The tests must instrument the storage layer directly to observe
what actually happened beneath the result.

### Instrumentation: `CountingMemory`

Wrap `SqliteMemory` with a thin counter subclass used only in tests. This is the
foundational tool for every test below.

```python
class CountingMemory(SqliteMemory):
    """SqliteMemory wrapper that counts anchor fetches from the database.

    Counts only actual DB reads — L1 hits (self.__mem__) are not counted
    because they represent already-loaded anchors, not new fetches.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.db_fetch_count = 0
        self.db_fetch_ids: list[str] = []

    def get(self, id):
        # If it's already in L1, this is not a new fetch
        if id in self.__mem__:
            return self.__mem__[id]
        # Going to DB — count it
        result = super().get(id)
        if result is not None:
            self.db_fetch_count += 1
            self.db_fetch_ids.append(str(id))
        return result

    def reset_counts(self):
        self.db_fetch_count = 0
        self.db_fetch_ids.clear()
```

Additionally, add counters to `am_index.py` for test visibility:

```python
# In am_index.py — test-only counters, zero overhead in production
_stats = {"am_hits": 0, "am_misses": 0, "gt_hits": 0, "gt_misses": 0}

def reset_stats():
    for k in _stats:
        _stats[k] = 0
```

Increment `_stats["am_hits"]` in `am_query` on a non-None return, `"am_misses"` on
`None`. Increment `"gt_hits"` / `"gt_misses"` in `gt_query_targets` similarly.

---

### Test Suite Structure

The tests live in `jac/tests/runtimelib/test_graph_index.jac` and are organised into
four groups.

---

#### Group 1 — GT Table Correctness

Verifies that the topology tables contain exactly what the anchor store implies.

**T1.1 — Edge write populates GT**

```
Setup:  seed root → [TargetNode × 3, OtherNode × 2]
        commit and close context (triggers SqliteMemory.sync)
Assert: SELECT COUNT(*) FROM edge_topology WHERE source_id = root_id = 5
        SELECT COUNT(*) FROM edge_topology WHERE target_type = 'TargetNode' = 3
        SELECT COUNT(*) FROM edge_topology WHERE target_type = 'OtherNode'  = 2
        SELECT COUNT(*) FROM node_topology  WHERE node_type  = 'TargetNode' = 3
```

**T1.2 — Edge delete removes GT row**

```
Setup:  T1.1 graph. Load one TargetNode, call destroy() on it.
Assert: edge_topology row for that edge_id is gone.
        node_topology row for that node_id is gone (destroyed node).
        Remaining edge_topology rows: 4 (not 5).
```

**T1.3 — GT rebuild from anchor store**

```
Setup:  T1.1 graph exists in anchors table.
        Manually DELETE FROM edge_topology (simulate GT corruption).
        Call rebuild_topology_index(mem).
Assert: edge_topology repopulated with 5 rows.
        SELECT COUNT(*) FROM edge_topology = 5.
```

**T1.4 — MRO fan-out in node_topology**

```
Setup:  node BaseContent {}; node PostNode :BaseContent: {}
        root → [PostNode × 2]
Assert: node_topology rows for each PostNode:
          (node_id, 'PostNode')    ← concrete type
          (node_id, 'BaseContent') ← parent type via MRO
        Total node_topology rows for the 2 PostNodes: 4 (2 types × 2 nodes)
```

---

#### Group 2 — AM Correctness

Verifies that AM contents are consistent with GT and the anchor store.

**T2.1 — am_put called at edge creation**

```
Setup:  create root → TargetNode in a fresh context (L1 hot).
Assert: am_index[str(root.id)]["TargetNode"] contains str(target.id)
        _stats["am_hits"] == 0 (no traversal yet)
```

**T2.2 — am_invalidate called at edge deletion**

```
Setup:  T2.1. Then destroy the TargetNode.
Assert: am_index.get(str(root.id)) is None  ← bucket was invalidated
```

**T2.3 — AM miss falls back to GT, then AM is populated**

```
Setup:  seed + commit + close context (L1 cleared).
        am_clear()  ← simulate server restart (AM empty, GT intact)
        reset_stats()
        Open new context. Traverse root --> (?:TargetNode).
Assert: _stats["am_misses"] == 1  ← AM miss (source bucket not in AM)
        _stats["gt_hits"]   == 1  ← GT answered
        am_index[str(root.id)]["TargetNode"] now populated  ← AM warmed
```

**T2.4 — Second traversal hits AM, not GT**

```
Setup:  continue from T2.3 (AM is now warm for root).
        reset_stats()
        Traverse root --> (?:TargetNode) again (same context).
Assert: _stats["am_hits"]   == 1  ← AM hit
        _stats["gt_hits"]   == 0  ← GT not consulted
```

**T2.5 — Parent-type query via MRO**

```
Setup:  node BaseContent {}; node PostNode :BaseContent: {}; node CommentNode :BaseContent: {}
        root → [PostNode × 2, CommentNode × 2, OtherNode × 1]
        Seed, commit, close, am_clear.
        Traverse root --> (?:BaseContent).
Assert: result set has 4 nodes (2 PostNode + 2 CommentNode)
        result set does NOT contain OtherNode instances
        GT row count for target_type='PostNode'    == 2
        GT row count for target_type='CommentNode' == 2
        am_index[root_id]["BaseContent"] has 4 entries
```

---

#### Group 3 — Fetch Count Reduction (the core metric)

These tests verify that the AM/GT path fetches fewer anchors from SQLite than the
local path would for the same query, using `CountingMemory` as the measurement tool.

The pattern for every test in this group:

```
1. Seed graph using CountingMemory. Commit. Close context.
2. am_clear() to simulate cold AM.
3. Open new context with the SAME CountingMemory instance.
4. Reset counts: mem.reset_counts(), reset_stats()
5. Traverse with JAC_INDEX_ENABLED=true.
6. Record: result_set_A, fetch_count_A, am_stats_A.
7. am_clear(). Reset counts.
8. Traverse again with JAC_INDEX_ENABLED=false.
9. Record: result_set_B, fetch_count_B.
10. Assert result_set_A == result_set_B  ← correctness
    Assert fetch_count_A < fetch_count_B  ← optimisation worked
    Assert fetch_count_A ≈ len(result_set_A)  ← only matching nodes were fetched
    Assert fetch_count_B ≈ fan_out  ← local path fetched all nodes
```

**T3.1 — Single-hop, low selectivity**

```
Graph:   root → [TargetNode × 5, OtherNode × 45]  (fan=50, selectivity=10%)
Expected fetch_count_A ≈ 5   (GT path: only TargetNodes)
Expected fetch_count_B ≈ 50  (local path: all 50 nodes)
Expected speedup:  fetch_count_B / fetch_count_A ≈ 10×
```

**T3.2 — Single-hop, high selectivity**

```
Graph:   root → [TargetNode × 45, OtherNode × 5]  (fan=50, selectivity=90%)
Expected fetch_count_A ≈ 45  (GT path: most nodes fetched anyway)
Expected fetch_count_B ≈ 50  (local path: all 50)
Expected speedup:  ~1.1× (marginal — high selectivity diminishes the gain)
```

This test exists to confirm the index does not *hurt* at high selectivity — the
overhead of the index lookup is not larger than the fetches saved.

**T3.3 — Below degree threshold (local path should be taken)**

```
Graph:   root → [TargetNode × 2, OtherNode × 3]  (fan=5, below threshold of 10)
Expected: _stats["am_hits"] == 0 and _stats["gt_hits"] == 0
          fetch_count_A == fetch_count_B  ← same path taken
```

This is a regression guard. If the heuristic is wrong and the index path is triggered
at low degree, this test catches it.

**T3.4 — Wildcard traversal (no type filter)**

```
Graph:   root → [TargetNode × 25, OtherNode × 25]  (fan=50)
Query:   root --> (no type filter)
Expected: _stats["am_hits"] == 0 and _stats["gt_hits"] == 0
          fetch_count_A == fetch_count_B  ← index bypassed for wildcards
```

Wildcard traversals must use the existing loop. The AM is keyed by type and cannot
accelerate a query that requests all types.

**T3.5 — Edge-type filtered traversal**

```
Graph:   root -[WroteEdge]-> [PostNode × 5]
         root -[LikedEdge]-> [PostNode × 30]
Query:   root -[WroteEdge]->(?:PostNode)
Expected fetch_count_A ≈ 5   (only WroteEdge targets)
Expected fetch_count_B ≈ 35  (local path loads all outgoing edges first)
```

Verifies that `edge_type_name` is correctly extracted from the destination and used in
the GT query, not just `target_type_name`.

---

#### Group 4 — Mutation Consistency

Verifies that AM and GT remain consistent with the anchor store after graph mutations.
These catch the most likely class of bugs: stale index entries after edge changes.

**T4.1 — Add edge, traverse, remove edge, traverse again**

```
Step A: root → [TargetNode × 20, OtherNode × 20]. Commit. Warm AM.
        Traverse (?:TargetNode) → result has 20 nodes. fetch_count ≈ 20.
Step B: Add 5 more TargetNodes. Commit.
        Traverse (?:TargetNode) → result must have 25 nodes.
        Assert: new nodes appear in result (AM was updated by am_put at build_edge time)
Step C: Destroy 3 of the TargetNodes. Commit.
        Traverse (?:TargetNode) → result must have 22 nodes.
        Assert: destroyed nodes not in result
        Assert: edge_topology rows for those edges gone
```

**T4.2 — AM invalidate on remove, GT is source of truth**

```
Setup:  root → [TargetNode × 20]. Commit. Warm AM via traversal.
        am_index[root_id]["TargetNode"] has 20 entries.
Step:   Remove one edge (destroy one TargetNode).
Assert: am_index.get(str(root.id)) is None  ← full bucket invalidated
        Next traversal hits GT (am_miss=1, gt_hit=1)
        GT returns 19 results.
        AM is repopulated with 19 entries.
```

**T4.3 — rebuild_topology_index restores consistency after corruption**

```
Setup:  root → [TargetNode × 20]. Commit.
        Manually corrupt: DELETE FROM edge_topology WHERE target_type='TargetNode' LIMIT 5
        am_clear().
Step:   Call rebuild_topology_index(mem).
Assert: edge_topology restored to 20 rows.
        Traversal returns 20 nodes with fetch_count ≈ 20.
```

---

### What Each Test Proves

| Test | Proves |
|---|---|
| T1.x | GT tables are populated/cleaned correctly by write/delete hooks |
| T2.x | AM is populated correctly; misses fall back to GT; AM warms on GT hit |
| T3.1 | The core benefit: fewer SQLite fetches at low selectivity |
| T3.2 | Index does not degrade high-selectivity traversals |
| T3.3 | Degree threshold heuristic correctly bypasses index at low fan-out |
| T3.4 | Wildcard traversals are not routed through the index |
| T3.5 | Edge-type filter is respected in GT queries |
| T4.x | AM and GT stay consistent with the anchor store across mutations |

**T3.1 is the definitive correctness-plus-benefit test.** If it passes — same result
set AND fewer fetches — the implementation is working as designed.

---

### Running the Tests in Isolation

Because AM is a process singleton, tests that mutate `am_index` must call `am_clear()`
and `reset_stats()` in their setup to avoid cross-test contamination. The recommended
pattern:

```python
def setup():
    am_clear()
    reset_stats()
    # create a fresh CountingMemory and fresh context
```

`JAC_INDEX_ENABLED` can be toggled between the two traversal runs in Group 3 without
restarting the process — the flag is read at traversal time, not at startup.

---

## Correctness Guarantees

**AM is never authoritative.** AM misses fall back to GT, GT misses fall back to the
edge-list loop. A corrupt or stale AM entry causes a missed optimization, not incorrect
results — the fallback always loads from the anchor store which is the source of truth.

**GT is derived, not primary.** The `anchors` table is always the source of truth. GT
rows are reconstructible via `rebuild_gt()` at any time. A GT row gap (e.g. from a
failed write hook) causes an AM/GT miss which falls back to the edge-list loop.

**Access control is never skipped.** The AM/GT path calls `check_read_access(target)` on
every bulk-fetched anchor before adding it to the result set (see Part 3 pseudocode).

**Atomicity.** GT writes are deferred to the same `SqliteMemory.sync()` transaction as
anchor writes. If the process dies before sync, the GT row is absent — the next
traversal falls back to the edge-list loop and the GT is reconstructed on the next
`rebuild_gt()` call (or next `build_edge()` call for the same edge if it is recreated).

---

## Files Changed / Created

| Action | File | Reason |
|---|---|---|
| **Create** | `jac/jaclang/runtimelib/am_index.py` | AM index, GT helpers, rebuild utility |
| **Modify** | `jac/jaclang/runtimelib/impl/memory.impl.jac` | Add topology tables in `_ensure_connection` |
| **Modify** | `jac/jaclang/jac0core/runtime.jac` | `build_edge` write hook (AM + GT) |
| **Modify** | `jac/jaclang/jac0core/runtime.jac` | `remove_edge` invalidation hook (AM + GT) |
| **Modify** | `jac/jaclang/jac0core/runtime.jac` | `edges_to_nodes` fast path |
| **Modify** | `jac/jaclang/jac0core/archetype.jac` | Add `node_type_name`, `edge_type_name` to `ObjectSpatialDestination` |
| **Modify** | filter compilation pass | Populate the two new attributes at compile time |
| **Create** | `jac/tests/runtimelib/test_graph_index.jac` | Integration tests |

Total: 2 new files, 5–6 modified files. No changes to the `anchors` table schema, no
changes to the pickle serialisation format, no changes to the public Jac language API.

**jac-scale files are not touched.** `ScaleTieredMemory` and its MongoDB/Redis backends
are out of scope. The `_get_sqlite` helper returns `None` for any `ScaleTieredMemory`
instance, so the index is simply inactive in jac-scale deployments — no errors, no
degraded behaviour beyond the absence of the optimisation.

---

## Future Work: jac-scale Path

This section describes what a jac-scale implementation would require. It is intentionally
not part of the current scope.

### Context

`ScaleTieredMemory` in
[jac-scale/jac_scale/impl/memory_hierarchy.main.impl.jac](jac-scale/jac_scale/impl/memory_hierarchy.main.impl.jac)
uses:

- **Redis** as L2 (cache)
- **MongoDB** as L3 (persistence) when available, falling back to `SqliteMemory`

When MongoDB is the L3, `_get_sqlite` returns `None` and GT is silently disabled.

### GT backend options for jac-scale

**Option A — MongoDB topology collection (recommended starting point)**

A dedicated `graph_topology` collection in the existing MongoDB database:

```
{ source_id, target_id, edge_type, target_type, root_id }
```

Compound index on `{source_id, edge_type, target_type}`. Query is a single
`find({source_id: X, target_type: T})`. No new infrastructure dependency — uses the
existing Motor/PyMongo connection. Multi-hop still requires application-side iteration.

**Option B — FalkorDB in Redis (higher capability, higher friction)**

FalkorDB (RedisGraph successor) runs as a Redis module in the existing Redis instance.
Queries are Cypher — multi-hop can be resolved server-side in a single round-trip.
Blocked by: FalkorDB module availability on managed Redis providers (ElastiCache,
Upstash, etc. do not support it by default).

### Required code changes for jac-scale GT

1. Add a `TopologyBackend` protocol to `am_index.py`:
   ```python
   class TopologyBackend(Protocol):
       def write_edge(self, eanch, source, target) -> None: ...
       def delete_edge(self, edge_id) -> None: ...
       def query_targets(self, source_id, edge_type, target_type) -> list[str] | None: ...
       def rebuild(self, mem) -> None: ...
   ```

2. Rename the current SQLite implementations to `SqliteTopology(TopologyBackend)`.

3. Implement `MongoTopology(TopologyBackend)` or `FalkorDBTopology(TopologyBackend)`.

4. In `am_index.py`, replace the `_get_sqlite` calls with a `get_topology_backend(mem)`
   factory that returns the appropriate backend based on the mem type.

5. The AM layer (`am_index`, `am_put`, `am_query`, `am_invalidate`) requires zero changes
   — it is already backend-agnostic.

The SQLite implementation built in this scope serves as the reference implementation and
test harness for the protocol. The jac-scale path is a drop-in substitution of the
backend, not a new architecture.
