# SAM + GTI Implementation Report

**Files covered:**
- [`jac/jaclang/runtimelib/sam_gti.jac`](../jac/jaclang/runtimelib/sam_gti.jac) — declarations and module-level globals
- [`jac/jaclang/runtimelib/impl/sam_gti.impl.jac`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac) — all implementations
- [`jac/jaclang/jac0core/runtime.jac`](../jac/jaclang/jac0core/runtime.jac) — read path (traversal query, `edges_to_nodes`)
- [`jac-scale/jac_scale/tests/test_gti_scale.jac`](../jac-scale/jac_scale/tests/test_gti_scale.jac) — Redis/MongoDB integration tests
- [`jac/tests/runtimelib/test_graph_index.jac`](../jac/tests/runtimelib/test_graph_index.jac) — SQLite unit tests

---

## Table of Contents

1. [Why This Exists — The Problem](#1-why-this-exists--the-problem)
2. [Architecture: Three Layers](#2-architecture-three-layers)
3. [Data Structures](#3-data-structures)
   - [3.1 SAM — Sparse Adjacency Matrix](#31-sam--sparse-adjacency-matrix)
   - [3.2 GTI SQLite — Graph Topology Index](#32-gti-sqlite--graph-topology-index)
   - [3.3 GTI Redis — Scale Backend](#33-gti-redis--scale-backend)
4. [Qualified Names — Collision Prevention](#4-qualified-names--collision-prevention)
   - [4.1 `_qname` helper](#41-_qname-helper)
   - [4.2 `get_type_mro` helper](#42-get_type_mro-helper)
5. [Write Path — How Edges Get Indexed](#5-write-path--how-edges-get-indexed)
   - [5.1 SAM write — `sam_put`](#51-sam-write--sam_put)
   - [5.2 GTI SQLite write — `_gti_write_edge`](#52-gti-sqlite-write--_gti_write_edge)
   - [5.3 GTI Redis write — `_gti_write_edge_redis`](#53-gti-redis-write--_gti_write_edge_redis)
6. [Read Path — How Traversals Use the Index](#6-read-path--how-traversals-use-the-index)
   - [6.1 Decision: use index or not?](#61-decision-use-index-or-not)
   - [6.2 Qualified name extraction](#62-qualified-name-extraction)
   - [6.3 SAM → GTI → fallback](#63-sam--gti--fallback)
7. [Delete Path](#7-delete-path)
   - [7.1 `sam_invalidate`](#71-sam_invalidate)
   - [7.2 `_gti_delete_edge` / `_gti_delete_edge_redis`](#72-_gti_delete_edge--_gti_delete_edge_redis)
   - [7.3 `_gti_delete_node` / `_gti_delete_node_redis`](#73-_gti_delete_node--_gti_delete_node_redis)
8. [Rebuild](#8-rebuild)
   - [8.1 SQLite rebuild](#81-sqlite-rebuild)
   - [8.2 Redis rebuild](#82-redis-rebuild)
9. [Migration — `migrate_to_qualified_types`](#9-migration--migrate_to_qualified_types)
10. [Backend Detection](#10-backend-detection)
11. [Thread Safety and Scale Consistency](#11-thread-safety-and-scale-consistency)
12. [Environment Variables](#12-environment-variables)
13. [Stats and Observability](#13-stats-and-observability)
14. [Test Coverage](#14-test-coverage)
15. [Full Call Graph](#15-full-call-graph)

---

## 1. Why This Exists — The Problem

When you write a typed traversal in Jac such as:

```jac
results = [-->(?:PostNode)];
```

the runtime needs to find all `PostNode` neighbours of the current node. Without an index, the only option is to:

1. Scan **every edge** on the source node
2. Load each `EdgeAnchor` from storage (SQLite or MongoDB)
3. Deserialize the binary blob
4. Load the target `NodeAnchor`
5. Deserialize it too
6. Check `isinstance(target.archetype, PostNode)`

On a dense hub node with hundreds or thousands of edges this is a full table scan on **every single traversal**. For a social graph where a popular user follows thousands of others, every `[-->(?:PostNode)]` call would read and deserialize the entire neighbourhood.

SAM and GTI together eliminate this cost by maintaining a pre-computed, type-indexed view of the graph structure.

---

## 2. Architecture: Three Layers

```
 Request: [-->(?:PostNode)]
     │
     ▼
┌────────────────────────────────────────────┐
│  SAM  (L1.5 — in-process memory)          │
│  sam_index[src_uuid]["n:app.PostNode"]     │  dict in RAM
│  = ["tgt1-uuid", "tgt2-uuid", ...]        │  nanosecond lookup
│  Volatile — cleared on process restart    │  per-worker singleton
└──────────────────┬─────────────────────────┘
                   │ cache miss
                   ▼
┌────────────────────────────────────────────┐
│  GTI  (L2 — persistent index)             │
│                                            │
│  SQLite (jac start):                       │
│    node_topology table                     │  durable across restarts
│    edge_topology table                     │  same file as anchors
│                                            │
│  Redis (jac scale):                        │
│    jac:topo:n:{src}:{type} → SET{targets} │  shared across workers
│    jac:topo:e:{src}:{type} → SET{targets} │  Redis native SMEMBERS/SINTER
└──────────────────┬─────────────────────────┘
                   │ GTI miss (first boot / no index)
                   ▼
┌────────────────────────────────────────────┐
│  Full edge scan (fallback)                 │
│  Read anchors table / MongoDB collection   │  original slow path
│  Deserialize every EdgeAnchor + target     │  always correct
└────────────────────────────────────────────┘
```

The fast path is only activated when:
- A persistence backend is present (SQLite or Redis)
- The traversal has at least one type filter (target type or edge type)
- The source node exceeds the degree threshold (default: 10 edges)

Below that threshold a linear scan is faster than an index lookup.

---

## 3. Data Structures

### 3.1 SAM — Sparse Adjacency Matrix

**Declaration:** [`sam_gti.jac:69-71`](../jac/jaclang/runtimelib/sam_gti.jac#L69-L71)

```jac
glob sam_index: dict[str, dict[str, list[str]]] = defaultdict(
    lambda: defaultdict(list)
);
```

Structure:
```
sam_index[source_uuid_str][column_key] = [target_uuid_str, ...]
```

**Column key format:**

| Prefix | Meaning | MRO fan-out |
|--------|---------|-------------|
| `"n:module.NodeType"` | node-type column | yes — PostNode also writes to n:BaseContent |
| `"e:module.EdgeType"` | edge-type column | no — edges have no inheritance |

**Miss semantics — two distinct cases:**

| SAM state | Meaning | Action |
|-----------|---------|--------|
| `sam_index.get(src)` is `None` | Bucket absent — source never indexed | Fall back to GTI |
| bucket present but `bucket.get(col)` is `None` | Column never written for this source | Fall back to GTI |
| bucket present and `bucket[col]` is `[]` | Column indexed, zero matching targets | Return empty list — no GTI call |

This distinction is critical: an empty list `[]` is a **valid hit** meaning "we checked and there are no PostNode neighbours." `None` means "we don't know yet."

**Example state** after indexing `root → [PostNode(p1), PostNode(p2), OtherNode(o1)]` where `PostNode` extends `BaseContent`:

```python
sam_index["root-uuid"] = {
    "n:app.PostNode":        ["p1-uuid", "p2-uuid"],
    "n:app.BaseContent":     ["p1-uuid", "p2-uuid"],   # MRO fan-out
    "n:app.OtherNode":       ["o1-uuid"],
    "e:jaclang.GenericEdge": ["p1-uuid", "p2-uuid", "o1-uuid"],
}
```

A query for `[-->(?:BaseContent)]` hits `"n:app.BaseContent"` and returns both PostNode IDs — without ever touching storage.

### 3.2 GTI SQLite — Graph Topology Index

**Schema** (created inside `SqliteMemory._ensure_connection()`):

```sql
CREATE TABLE IF NOT EXISTS node_topology (
    node_id   TEXT NOT NULL,
    node_type TEXT NOT NULL,
    root_id   TEXT,
    PRIMARY KEY (node_id, node_type)
);

CREATE TABLE IF NOT EXISTS edge_topology (
    edge_id     TEXT PRIMARY KEY,
    source_id   TEXT NOT NULL,
    target_id   TEXT NOT NULL,
    edge_type   TEXT NOT NULL,
    target_type TEXT NOT NULL
);
```

**Key design decisions:**

- `node_topology` stores **one row per (node, MRO type) pair**. A `PostNode(BaseContent)` gets two rows: `(p1, app.PostNode, root)` and `(p1, app.BaseContent, root)`. This is what makes parent-type queries work without runtime MRO traversal.
- `edge_topology` stores the direct type of the target (not all MRO types). Type-filtered queries JOIN against `node_topology` to resolve the MRO.
- Both tables live in the same SQLite file as the `anchors` table — no separate database or process needed.
- `INSERT OR IGNORE` on `node_topology` and `INSERT OR REPLACE` on `edge_topology` make writes idempotent — safe to call multiple times without duplicates.

### 3.3 GTI Redis — Scale Backend

**Key namespace:**

```
jac:topo:n:{source_uuid}:{module.NodeType}  →  Redis SET of target UUIDs
jac:topo:e:{source_uuid}:{module.EdgeType}  →  Redis SET of target UUIDs
```

**Example Redis keys** after building a graph where `root` connects to `p1`, `p2` (PostNode) and `o1` (OtherNode):

```
jac:topo:n:{root-uuid}:app.PostNode    →  {p1-uuid, p2-uuid}
jac:topo:n:{root-uuid}:app.BaseContent →  {p1-uuid, p2-uuid}
jac:topo:n:{root-uuid}:app.OtherNode   →  {o1-uuid}
jac:topo:e:{root-uuid}:jaclang.GenericEdge → {p1-uuid, p2-uuid, o1-uuid}
```

**Query operations:**

| Filter | Redis command | Notes |
|--------|--------------|-------|
| node type only | `SMEMBERS jac:topo:n:{src}:{type}` | single round-trip |
| edge type only | `SMEMBERS jac:topo:e:{src}:{type}` | single round-trip |
| both | `SINTER jac:topo:n:{src}:{ntype} jac:topo:e:{src}:{etype}` | server-side intersection |

`SINTER` is evaluated entirely on the Redis server — no Python-side set intersection needed.

**Invalidation channel:**

```
jac:topo:invalidate  →  Pub/Sub channel carrying source_uuid messages
```

All worker processes subscribe to this channel. When any worker modifies an edge (add or remove), it publishes the source UUID. All subscribers (including the caller) drop the SAM bucket for that source, ensuring consistency across workers.

---

## 4. Qualified Names — Collision Prevention

### 4.1 `_qname` helper

**Implementation:** [`sam_gti.impl.jac:11-16`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L11-L16)

```jac
impl _qname(arch: object) -> str {
    t = type(arch);
    mod: str = str(getattr(t, '__module__', '') or '');
    name: str = str(getattr(t, '__name__', '') or '');
    return mod + '.' + name;
}
```

**What it does:** Given any Python/Jac object (a node instance, an edge instance, or a type class), returns `"module.ClassName"`.

**Why `getattr` with `str()` cast:** The Jac type checker treats `getattr()` return as `Unknown`. The `str()` cast satisfies the type checker while being a no-op at runtime since the values are already strings.

**Why `or ''`:** Guards against `None` from `__module__` being absent (e.g. C extension types) before the `str()` cast.

**Examples:**

| Input | `__module__` | `__name__` | Output |
|-------|-------------|-----------|--------|
| `PostNode()` instance from `gti_scale_app.jac` | `gti_scale_app` | `PostNode` | `gti_scale_app.PostNode` |
| `GenericEdge()` from jaclang internals | `jaclang.jac0core.archetype` | `GenericEdge` | `jaclang.jac0core.archetype.GenericEdge` |
| `None` | `builtins` | `NoneType` | `builtins.NoneType` |

**Collision scenario prevented:**

```
# app_v1/models.jac
node PostNode { has title: str; }

# app_v2/models.jac
node PostNode { has body: str; }
```

Without qualification: both write to `n:PostNode` → wrong query results.
With qualification: `n:app_v1.models.PostNode` and `n:app_v2.models.PostNode` → fully isolated.

### 4.2 `get_type_mro` helper

**Implementation:** [`sam_gti.impl.jac:42-52`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L42-L52)

```jac
impl get_type_mro(instance: object) -> list[str] {
    result = [];
    for cls in type(instance).__mro__ {
        mod = getattr(cls, '__module__', '') or '';
        if mod.startswith('jaclang') or mod.startswith('builtins') or cls.__name__ == 'object' {
            break;
        }
        result.append(mod + '.' + getattr(cls, '__name__', ''));
    }
    return result;
}
```

**What it does:** Walks Python's Method Resolution Order (MRO) of an instance's type and collects all user-defined Jac type names as qualified strings.

**Stop conditions — why each is needed:**

| Condition | Why |
|-----------|-----|
| `mod.startswith('jaclang')` | jaclang base classes (`NodeArchetype`, `EdgeArchetype`, etc.) must not become topology keys — they would match every node/edge in the graph |
| `mod.startswith('builtins')` | Prevents `NoneType`, `int`, `str`, `object` from leaking as keys |
| `cls.__name__ == 'object'` | Belt-and-suspenders — catches `object` even if somehow `__module__` is not `builtins` |

**MRO fan-out example:**

```jac
node BaseContent { has val: int = 0; }
node PostNode(BaseContent) { has val: int = 0; }
```

```python
get_type_mro(PostNode())
# → ["app.PostNode", "app.BaseContent"]

get_type_mro(None)
# → []  (NoneType.__module__ == 'builtins' → immediate break)
```

This fan-out is what enables parent-type queries to work. When you traverse `[-->(?:BaseContent)]`, the index key `n:app.BaseContent` already contains `PostNode` IDs because they were written there at edge-creation time.

---

## 5. Write Path — How Edges Get Indexed

The write path has three parallel implementations depending on the backend: SAM only (in-memory), GTI SQLite, and GTI Redis. All three use `get_type_mro` and `_qname` so keys are always qualified.

### 5.1 SAM write — `sam_put`

**Implementation:** [`sam_gti.impl.jac:57-78`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L57-L78)

```jac
impl sam_put(
    source_id: UUID, target_id: UUID, target_arch: object, edge_arch: object
) -> None {
    src_str = str(source_id);
    tgt_str = str(target_id);
    lock = _get_lock(src_str);
    with lock {
        bucket = sam_index[src_str];
        for type_name in get_type_mro(target_arch) {
            col = 'n:' + type_name;
            if tgt_str not in bucket[col] {
                bucket[col].append(tgt_str);
            }
        }
        edge_col = 'e:' + _qname(edge_arch);
        if tgt_str not in bucket[edge_col] {
            bucket[edge_col].append(tgt_str);
        }
    }
}
```

**Steps:**
1. Acquire the per-source lock (`_get_lock`) — prevents concurrent writers from a multi-threaded server corrupting the same bucket
2. Iterate `get_type_mro(target_arch)` — fans out to all MRO ancestor types
3. Append `target_id` to each `n:type` column (deduplication check included)
4. Append `target_id` to the `e:EdgeType` column

**Called from:** `build_edge()` in single-server mode (SQLite or in-memory). Not called in scale mode — `sam_broadcast_invalidate` is called instead.

**Lock design:** Locks are per-source (not global). Two threads modifying edges from different source nodes never contend. A single mutex `_locks_mu` guards the `_locks` dict itself to safely create new per-source locks.

### 5.2 GTI SQLite write — `_gti_write_edge`

**Implementation:** [`sam_gti.impl.jac:144-177`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L144-L177)

```jac
impl _gti_write_edge(
    mem: object, eanch: object, source: object, target: object
) -> None {
    sqlite = _get_sqlite(mem);
    if sqlite is None { return; }
    sqlite._ensure_connection();
    if sqlite.__conn__ is None { return; }

    edge_type = _qname(eanch.archetype);
    target_type = _qname(target.archetype);
    root_id = str(target.root) if target.root else None;

    # node_topology: one row per MRO type of the target
    for t in get_type_mro(target.archetype) {
        sqlite.__conn__.execute(
            'INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id) '
            'VALUES (?, ?, ?)',
            (str(target.id), t, root_id)
        );
    }

    # edge_topology: one row for the edge
    sqlite.__conn__.execute(
        'INSERT OR REPLACE INTO edge_topology '
        '(edge_id, source_id, target_id, edge_type, target_type) '
        'VALUES (?, ?, ?, ?, ?)',
        (str(eanch.id), str(source.id), str(target.id), edge_type, target_type)
    );
    sqlite.__conn__.commit();
}
```

**Key decisions:**
- `INSERT OR IGNORE` on `node_topology`: if the row already exists (e.g. the same node connected twice from different sources) it is simply skipped — no error, no duplicate.
- `INSERT OR REPLACE` on `edge_topology`: if an edge is reconnected (same edge_id), the row is updated with fresh data.
- Immediate `commit()` after every write: keeps GTI in sync with `SqliteMemory.put()` — if the process crashes after the anchor is written, GTI reflects the same state.

### 5.3 GTI Redis write — `_gti_write_edge_redis`

**Implementation:** [`sam_gti.impl.jac:400-415`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L400-L415)

```jac
impl _gti_write_edge_redis(
    redis_client: object, eanch: object, source: object, target: object
) -> None {
    src_str = str(source.id);
    tgt_str = str(target.id);
    edge_type = _qname(eanch.archetype);
    pipe = redis_client.pipeline(transaction=False);
    for t in get_type_mro(target.archetype) {
        pipe.sadd(f"{_TOPO_PREFIX}:n:{src_str}:{t}", tgt_str);
    }
    pipe.sadd(f"{_TOPO_PREFIX}:e:{src_str}:{edge_type}", tgt_str);
    pipe.execute();
}
```

**Pipeline design:** All `SADD` commands for a single edge write are batched into one Redis pipeline. For a node with a 3-level inheritance chain, this is 4 commands (3 node-type + 1 edge-type) sent in one network round-trip instead of 4.

`transaction=False` means the pipeline is not wrapped in `MULTI/EXEC`. This is intentional — the individual `SADD` commands are idempotent (sets deduplicate automatically), so atomicity is not required and `transaction=False` is slightly faster.

**SAM is not updated:** In scale mode with multiple workers, directly updating the local SAM would create inconsistency — Worker A's SAM would be up-to-date while Workers B and C have stale buckets. Instead, `sam_broadcast_invalidate` is called, which publishes the source UUID to `jac:topo:invalidate`. All workers (including the caller) drop the bucket and repopulate lazily from Redis on the next traversal.

---

## 6. Read Path — How Traversals Use the Index

**Location:** [`runtime.jac:300-410`](../jac/jaclang/jac0core/runtime.jac#L300-L410), inside `edges_to_nodes()`.

### 6.1 Decision: use index or not?

```jac
INDEX_ENABLED: bool = os.environ.get('JAC_INDEX_ENABLED', 'true').lower()
    not in ('0', 'false', 'no');
DEGREE_THRESHOLD: int = int(os.environ.get('JAC_INDEX_DEGREE_THRESHOLD', '10'));

use_index = (
    INDEX_ENABLED
    and _index_active                          # SQLite or Redis present
    and nanch.is_populated()                   # source node is not transient
    and (target_type_name is not None
         or edge_type_name is not None)        # at least one type filter
    and destination.direction in [EdgeDir.OUT, EdgeDir.ANY]
    and len(nanch.edges) > DEGREE_THRESHOLD    # above degree threshold
);
```

**Why the degree threshold?** For a node with 3 edges, a linear scan deserializes 3 objects — faster than an index lookup. The threshold (default 10) is the crossover point below which the index overhead exceeds the scan cost. It is tunable via `JAC_INDEX_DEGREE_THRESHOLD`.

**Why direction check?** The index currently only covers outgoing edges (`EdgeDir.OUT` / `EdgeDir.ANY`). Incoming-edge queries fall back to the slow path.

### 6.2 Qualified name extraction

```jac
target_type_name = (destination.nd.__module__ + '.' + destination.nd.__name__)
    if isinstance(destination.nd, type)
    else None;
edge_type_name = (destination.edge.__module__ + '.' + destination.edge.__name__)
    if isinstance(destination.edge, type)
    else None;
```

`destination.nd` and `destination.edge` are the **type classes** extracted from the traversal filter (e.g. `PostNode` and `FollowEdge`). This produces exactly the same `module.ClassName` format used during writes — the keys match on both sides.

`isinstance(..., type)` guards against non-type filters (e.g. an instance filter or `None`) that should not go through the index path.

### 6.3 SAM → GTI → fallback

**Node-type filter only — `[-->(?:PostNode)]`:**

```
1. n_col = "n:app.PostNode"
   target_ids = sam_query(source_id, n_col)

   → HIT: return cached list directly (no I/O)

   → MISS:
       if scale mode:
           gt_ids = gti_query_targets_redis(redis, source_id, None, "app.PostNode")
           # SMEMBERS jac:topo:n:{src}:app.PostNode
       else:
           gt_ids = gti_query_targets(mem, source_id, None, "app.PostNode")
           # SELECT DISTINCT et.target_id
           # FROM edge_topology et
           # JOIN node_topology nt ON et.target_id = nt.node_id
           # WHERE et.source_id = ? AND nt.node_type = ?

       sam_populate_from_gti(source_id, [(id, n_col) for id in gt_ids])
       # Warm SAM for next traversal

       → GTI MISS (no index yet): fall back to full edge scan
```

**Combined filter — `[-->(?:PostNode)?:FollowEdge]`:**

```
SAM path:
    n_col = "n:app.PostNode"
    e_col = "e:app.FollowEdge"
    node_ids = sam_query(source_id, n_col)
    edge_ids = sam_query(source_id, e_col)
    if either is None → GTI
    else → target_ids = set(node_ids) & set(edge_ids)  # Python intersection

GTI SQLite path:
    SELECT DISTINCT et.target_id
    FROM edge_topology et
    JOIN node_topology nt ON et.target_id = nt.node_id
    WHERE et.source_id = ?
      AND nt.node_type = ?
      AND et.edge_type = ?

GTI Redis path:
    SINTER jac:topo:n:{src}:app.PostNode
           jac:topo:e:{src}:app.FollowEdge
    # Server-side intersection — single round-trip
```

**Edge-type filter only — `[-->?:FollowEdge]`:**

```
SAM: sam_query(source_id, "e:app.FollowEdge")
GTI SQLite: SELECT target_id FROM edge_topology WHERE source_id=? AND edge_type=?
GTI Redis:  SMEMBERS jac:topo:e:{src}:app.FollowEdge
```

After any GTI hit, `sam_populate_from_gti` is called with the results so the next traversal from the same source hits SAM instead of GTI.

---

## 7. Delete Path

### 7.1 `sam_invalidate`

**Implementation:** [`sam_gti.impl.jac:80-86`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L80-L86)

```jac
impl sam_invalidate(source_id: UUID) -> None {
    src_str = str(source_id);
    lock = _get_lock(src_str);
    with lock {
        sam_index.pop(src_str, None);
    }
}
```

Drops the **entire source bucket** from SAM. Called from `remove_edge()` whenever any edge from a source node is removed. Simple and conservative — the whole bucket is invalidated even though only one edge changed. The bucket repopulates lazily from GTI on the next traversal.

In scale mode, `sam_broadcast_invalidate` publishes the source UUID to `jac:topo:invalidate` and all workers call `sam_invalidate` on receipt.

### 7.2 `_gti_delete_edge` / `_gti_delete_edge_redis`

**Implementations:** [`sam_gti.impl.jac:179-192`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L179-L192), [`sam_gti.impl.jac:417-433`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L417-L433)

**SQLite:**
```jac
sqlite.__conn__.execute(
    'DELETE FROM edge_topology WHERE edge_id = ?', (str(edge_id), )
);
```

Only removes the `edge_topology` row. `node_topology` rows for the target node are **not** removed — a node continues to exist after its edges are removed.

**Redis:**
```jac
edge_type = _qname(edge_arch);
pipe = redis_client.pipeline(transaction=False);
for t in get_type_mro(target_arch) {
    pipe.srem(f"{_TOPO_PREFIX}:n:{src_str}:{t}", tgt_str);
}
pipe.srem(f"{_TOPO_PREFIX}:e:{src_str}:{edge_type}", tgt_str);
pipe.execute();
```

**Precise removal** — `SREM` removes only the specific target UUID from each set. The source bucket's sets remain intact for other targets. This is more surgical than `sam_invalidate` (which drops the whole bucket) — after a Redis SREM the key is still valid for all remaining targets.

The function receives `target_arch` and `edge_arch` directly (not just IDs) because it needs to reconstruct the same MRO-expanded key names that were written during `_gti_write_edge_redis`.

### 7.3 `_gti_delete_node` / `_gti_delete_node_redis`

**Implementations:** [`sam_gti.impl.jac:194-212`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L194-L212), [`sam_gti.impl.jac:435-452`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L435-L452)

Called when a `NodeAnchor` is **destroyed** (not just disconnected). Removes all topology rows for the node — both as a source and as a target.

**SQLite:**
```sql
DELETE FROM node_topology WHERE node_id = ?
DELETE FROM edge_topology WHERE source_id = ? OR target_id = ?
```

**Redis:** Scans for all keys matching `jac:topo:n:{node_id}:*` and `jac:topo:e:{node_id}:*` using a cursor-based `SCAN` loop, then deletes them in batches.

```jac
for pattern in [
    f"{_TOPO_PREFIX}:n:{node_str}:*",
    f"{_TOPO_PREFIX}:e:{node_str}:*"
] {
    cursor = 0;
    while True {
        (cursor, keys) = redis_client.scan(cursor, match=pattern, count=100);
        if keys { redis_client.delete(*keys); }
        if cursor == 0 { break; }
    }
}
```

`SCAN` is used instead of `KEYS` because `KEYS` blocks the Redis server for the duration of the scan — unsafe on large keyspaces in production. `SCAN` iterates incrementally and never blocks. Node destruction is rare so the multi-round-trip overhead is acceptable.

---

## 8. Rebuild

Rebuild is needed when:
- The server starts for the first time with an existing anchor store (GTI tables don't exist yet)
- GTI becomes stale or corrupt and needs to be reconstructed
- After running `migrate_to_qualified_types`

### 8.1 SQLite rebuild

**Functions:** [`sam_gti.impl.jac:273-369`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L273-L369)

`rebuild_gti(mem)` — two-pass scan of the `anchors` table:

**Pass 1 — NodeAnchors:**
```
for each blob in anchors:
    anchor = pickle.loads(blob)
    if isinstance(anchor, NodeAnchor) and anchor.is_populated():
        node_type_map[str(anchor.id)] = _qname(anchor.archetype)
        for t in get_type_mro(anchor.archetype):
            INSERT OR IGNORE INTO node_topology (node_id, node_type, root_id)
```

Builds an in-memory `node_id → qualified_type` map for use in Pass 2.

**Pass 2 — EdgeAnchors:**
```
for each blob in anchors:
    anchor = pickle.loads(blob)
    if isinstance(anchor, EdgeAnchor) and anchor.is_populated():
        target_type = node_type_map.get(str(anchor.target.id))
        if target_type:
            INSERT OR REPLACE INTO edge_topology
                (edge_id, source_id, target_id, edge_type, target_type)
```

Two passes are required because an EdgeAnchor's `target_type` must be looked up from the node map, and edges may appear before their target nodes in the blob order.

`rebuild_topology_index(mem)` wraps `rebuild_gti` and also warms SAM immediately after:

```jac
cur = sqlite.__conn__.execute(
    'SELECT source_id, target_id, edge_type, target_type FROM edge_topology'
);
for (src, tgt, etype, ttype) in cur.fetchall() {
    bucket = sam_index[src];
    bucket['n:' + ttype].append(tgt);
    bucket['e:' + etype].append(tgt);
}
```

This pre-warms every SAM bucket from the rebuilt GTI so the first traversal after a rebuild is also fast.

### 8.2 Redis rebuild

**Functions:** [`sam_gti.impl.jac:493-533`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L493-L533)

`rebuild_gti_redis(redis_client, mongo_backend)` — same two-pass logic but over MongoDB:

**Pass 1 — NodeAnchors:**
```
node_type_map: dict[str, list[str]] = {}
for anchor in mongo_backend.query():
    if isinstance(anchor, NodeAnchor) and anchor.is_populated():
        node_type_map[str(anchor.id)] = get_type_mro(anchor.archetype)
```

Note: stores the **full MRO list** (not just the primary type) because Redis needs to SADD to all ancestor keys.

**Pass 2 — EdgeAnchors (with pipeline):**
```
pipe = redis_client.pipeline(transaction=False)
for anchor in mongo_backend.query():
    if isinstance(anchor, EdgeAnchor) and anchor.is_populated():
        for t in node_type_map.get(str(anchor.target.id), []):
            pipe.sadd(f"jac:topo:n:{src}:{t}", tgt)
        pipe.sadd(f"jac:topo:e:{src}:{edge_type}", tgt)
pipe.execute()
```

All `SADD` commands for all edges are batched into a single pipeline and executed in one network call. For a graph with 10,000 edges and 3-level inheritance, this is ~40,000 Redis commands sent as one batch.

`rebuild_topology_index_scale` clears SAM after Redis rebuild (unlike the SQLite version which warms SAM). SAM warms lazily in scale mode because warming eagerly across a multi-worker deployment would require broadcasting all SAM contents — impractical.

---

## 9. Migration — `migrate_to_qualified_types`

**Implementation:** [`sam_gti.impl.jac:539-583`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L539-L583)

This is a one-time operation needed when upgrading a deployed Jac application from a version that stored bare type names (e.g. `PostNode`) to the current version that stores qualified names (e.g. `app.PostNode`).

**Why a full truncate+rebuild and not an in-place UPDATE?**

`rebuild_gti` uses `INSERT OR IGNORE`. If bare-name rows already exist in `node_topology`, the `INSERT OR IGNORE` for the new qualified-name rows would succeed — but the old bare-name rows would remain alongside them. Any query using `WHERE node_type = 'app.PostNode'` would find the new rows, but old code (or tests) expecting `WHERE node_type = 'PostNode'` would still find the old rows too. The only safe approach is to wipe everything and rebuild from the ground truth (the pickled anchors / MongoDB documents).

**SQLite path:**

```jac
sqlite.__conn__.execute('DELETE FROM node_topology');
sqlite.__conn__.execute('DELETE FROM edge_topology');
sqlite.__conn__.commit();
rebuild_gti(mem);   # repopulates with qualified names
sam_clear();
return {'backend': 'sqlite', 'status': 'migrated'};
```

**Redis path:**

```jac
cursor = 0;
deleted = 0;
while True {
    (cursor, keys) = redis_client.scan(
        cursor, match=f"{_TOPO_PREFIX}:*", count=200
    );
    if keys {
        redis_client.delete(*keys);
        deleted += len(keys);
    }
    if cursor == 0 { break; }
}
count = rebuild_gti_redis(redis_client, mongo_backend);
sam_clear();
return {'backend': 'redis', 'keys_flushed': str(deleted), 'edges_rebuilt': str(count)};
```

`SCAN` with `count=200` processes keys in batches — avoids blocking the Redis server for large key spaces.

**WARNING:** There is a brief window between the flush and the rebuild during which GTI is empty. Traversals during this window fall back to the full edge scan. No data is lost — the graph anchors are unchanged — only performance degrades temporarily. Run during a maintenance window or low-traffic period.

**How to invoke** from a running server (via the `RunMigration` walker pattern):

```jac
walker:pub RunMigration {
    can migrate with Root entry {
        import from jaclang { JacRuntime as Jac }
        import from jaclang.runtimelib.sam_gti { migrate_to_qualified_types }
        ctx = Jac.get_context();
        result = migrate_to_qualified_types(ctx.mem);
        report result;
    }
}
```

---

## 10. Backend Detection

Both `_get_sqlite` and `_get_scale_topo` are **lazy introspection functions** — they inspect the `mem` object at call time to determine which backend is active.

### `_get_sqlite` — [`sam_gti.impl.jac:129-139`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L129-L139)

```jac
impl _get_sqlite(mem: object) -> (object | None) {
    import from jaclang.runtimelib.memory { SqliteMemory }
    if isinstance(mem, SqliteMemory) {
        return mem;
    }
    l3 = getattr(mem, 'l3', None);
    if isinstance(l3, SqliteMemory) {
        return l3;
    }
    return None;
}
```

Handles two cases:
- **Bare `SqliteMemory`** — returned directly (`jac start` with no tiered memory)
- **`TieredMemory.l3` is `SqliteMemory`** — unwrapped from the tiered wrapper
- **Anything else** — returns `None` (in-memory `jac run`, or scale mode with MongoDB)

### `_get_scale_topo` — [`sam_gti.impl.jac:378-398`](../jac/jaclang/runtimelib/impl/sam_gti.impl.jac#L378-L398)

```jac
impl _get_scale_topo(mem: object) -> (tuple | None) {
    try {
        import from jac_scale.memory_hierarchy {
            ScaleTieredMemory, RedisBackend, MongoBackend
        };
    } except ImportError {
        return None;
    }
    if not isinstance(mem, ScaleTieredMemory) { return None; }
    l2 = getattr(mem, 'l2', None);
    l3 = getattr(mem, 'l3', None);
    if (isinstance(l2, RedisBackend) and l2.redis_client is not None
        and isinstance(l3, MongoBackend) and l3.client is not None) {
        return (l2.redis_client, l3);
    }
    return None;
}
```

The `try/except ImportError` is the key design point: `jac_scale` is imported **inside the function body**, not at module level. This means `sam_gti` can be imported in a base `jac` installation without `jac_scale` installed — no hard dependency. Returns `None` in all non-scale configurations, making the caller's `if scale is not None` guard trivially false.

**Deployment matrix:**

| Mode | `_get_sqlite` | `_get_scale_topo` | GTI backend |
|------|--------------|------------------|-------------|
| `jac run` (in-memory) | `None` | `None` | disabled |
| `jac start` (SQLite) | `SqliteMemory` | `None` | SQLite |
| `jac scale` (Redis+MongoDB) | `None` | `(redis, mongo)` | Redis |

---

## 11. Thread Safety and Scale Consistency

### Single-server thread safety

SAM writes use **per-source locks:**

```jac
glob _locks: dict[str, Lock] = {};
glob _locks_mu: Lock = Lock();

impl _get_lock(source_id: str) -> Lock {
    with _locks_mu {
        if source_id not in _locks {
            _locks[source_id] = Lock();
        }
        return _locks[source_id];
    }
}
```

`_locks_mu` is a single global mutex that only guards the `_locks` dict itself (creating new per-source locks). Once a per-source lock is acquired, `_locks_mu` is released — two threads modifying different source nodes never contend with each other.

GTI SQLite writes go through SQLite's own locking. Since `SqliteMemory` uses a single connection per process and SQLite has write serialization, GTI SQLite is thread-safe by default.

### Multi-worker scale consistency

In jac-scale, multiple worker processes each have their own SAM. A write on Worker A does not automatically appear in Worker B's SAM.

The solution is **pub/sub invalidation:**

1. Worker A calls `build_edge()` → writes to MongoDB + Redis GTI → calls `sam_broadcast_invalidate(redis_client, source_id)`
2. `sam_broadcast_invalidate` publishes `str(source_id)` to `jac:topo:invalidate`
3. All workers (including A) have a background subscriber thread that receives the message and calls `sam_invalidate(source_id)` — dropping the bucket
4. The next traversal from any worker that hits the now-absent bucket falls back to Redis GTI and re-warms SAM

This means SAM is **eventually consistent across workers** — there is a brief window after a write where a worker may serve a stale SAM bucket. In practice this window is the pub/sub round-trip latency (microseconds). For the traversal use case (read-heavy, writes are infrequent), this is acceptable.

---

## 12. Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAC_INDEX_ENABLED` | `"true"` | Set to `"false"`, `"0"`, or `"no"` to disable SAM/GTI entirely |
| `JAC_INDEX_DEGREE_THRESHOLD` | `"10"` | Minimum edge count before index is used for a node |
| `REDIS_URL` | unset | Redis connection URL for jac-scale (e.g. `redis://localhost:6379/0`) |
| `MONGODB_URI` | unset | MongoDB connection URI for jac-scale |

---

## 13. Stats and Observability

**Declaration:** [`sam_gti.jac:78-83`](../jac/jaclang/runtimelib/sam_gti.jac#L78-L83)

```jac
glob _stats: dict[str, int] = {
    'sam_hits':   0,
    'sam_misses': 0,
    'gti_hits':   0,
    'gti_misses': 0,
};
```

Four counters track the cache performance at each layer. `reset_stats()` zeroes them (used in tests). In production, these can be read and exported to a metrics system to monitor hit rates and identify nodes that consistently miss the index (indicating a need to tune `JAC_INDEX_DEGREE_THRESHOLD`).

Counter semantics:
- `sam_hits` — SAM returned a result (list or empty list)
- `sam_misses` — SAM bucket absent or column never written; fell through to GTI
- `gti_hits` — GTI query executed and returned rows (possibly empty)
- `gti_misses` — GTI not available or query threw an exception; fell through to full scan

---

## 14. Test Coverage

### SQLite unit tests — [`jac/tests/runtimelib/test_graph_index.jac`](../jac/tests/runtimelib/test_graph_index.jac)

| Group | Tests | What is covered |
|-------|-------|----------------|
| 1 — SAM cache | 4 tests | sam_put, sam_query hit/miss, sam_invalidate |
| 2 — GTI write | 3 tests | _gti_write_edge inserts correct rows |
| 3 — GTI query | 4 tests | gti_query_targets with node/edge/combined filters |
| 4 — GTI delete | 3 tests | _gti_delete_edge, _gti_delete_node cleanup |
| 5 — Rebuild | 3 tests | rebuild_gti, rebuild_topology_index, SAM warming |
| 6 — Qualified names | 6 tests | _qname, get_type_mro, None/builtins edge cases |
| 7 — Migration | 2 tests | migrate_to_qualified_types SQLite path, bare→qualified |

**Total: 25 SQLite tests**

### Redis/MongoDB integration tests — [`jac-scale/jac_scale/tests/test_gti_scale.jac`](../jac-scale/jac_scale/tests/test_gti_scale.jac)

Uses `testcontainers` (real Docker containers) + `jac start` subprocess for true end-to-end coverage.

| Group | Tests | What is covered |
|-------|-------|----------------|
| 1 — Qualified names in Redis | 2 tests | Keys written as `module.Type`, no bare keys, MRO fan-out scard |
| 2 — Typed traversal | 1 test | QueryByBase returns only PostNode results, not OtherNode |
| 3 — Edge deletion | 1 test | _gti_delete_edge_redis SREM reduces scard by 1 |
| 4 — Migration | 1 test | bare keys injected → RunMigration → bare gone, qualified rebuilt |

**Total: 5 Redis integration tests**

**Requires:** Docker Desktop running, `testcontainers` installed (`pip install testcontainers`).

---

## 15. Full Call Graph

```
build_edge()  ─────────────────────────────────────────────────
  │ (single-server SQLite)                                     │
  ├─► _gti_write_edge(mem, eanch, source, target)             │ (scale)
  │     └─► _get_sqlite(mem)                                  │
  │     └─► get_type_mro(target.archetype) → INSERT OR IGNORE │
  │     └─► _qname(eanch.archetype)        → INSERT OR REPLACE│
  │                                                            │
  ├─► sam_put(source_id, target_id, target_arch, edge_arch)   │
  │     └─► get_type_mro(target_arch)      → sam_index write  │
  │     └─► _qname(edge_arch)              → sam_index write  │
  │                                                            ▼
  └─► _gti_write_edge_redis(redis, eanch, source, target)
        └─► get_type_mro(target.archetype) → SADD pipeline
        └─► _qname(eanch.archetype)        → SADD pipeline
        └─► sam_broadcast_invalidate(redis, source_id)
              └─► redis.publish("jac:topo:invalidate", src_uuid)
                    └─► [all workers] sam_invalidate(source_id)

remove_edge() ─────────────────────────────────────────────────
  ├─► _gti_delete_edge(mem, edge_id)
  │     └─► DELETE FROM edge_topology WHERE edge_id = ?
  │
  ├─► _gti_delete_edge_redis(redis, src_id, tgt_id, tgt_arch, edge_arch)
  │     └─► get_type_mro(tgt_arch)   → SREM pipeline
  │     └─► _qname(edge_arch)        → SREM pipeline
  │
  ├─► sam_invalidate(source_id)       # single-server
  └─► sam_broadcast_invalidate(...)   # scale

destroy() ─────────────────────────────────────────────────────
  ├─► _gti_delete_node(mem, node_id)
  │     └─► DELETE FROM node_topology WHERE node_id = ?
  │     └─► DELETE FROM edge_topology WHERE source_id = ? OR target_id = ?
  └─► _gti_delete_node_redis(redis, node_id)
        └─► SCAN jac:topo:n:{node_id}:* → DELETE
        └─► SCAN jac:topo:e:{node_id}:* → DELETE

edges_to_nodes() ──────────────────────────────────────────────
  ├─► _get_sqlite(ctx.mem)   → _sqlite_active
  ├─► _get_scale_topo(ctx.mem) → _scale
  │
  ├─► [use_index path]
  │     ├─► sam_query(source_id, col)
  │     │     → HIT: return cached list
  │     │     → MISS:
  │     │           ├─► gti_query_targets(mem, ...)         # SQLite
  │     │           │     └─► SELECT ... FROM edge_topology
  │     │           │         JOIN node_topology ...
  │     │           └─► gti_query_targets_redis(redis, ...) # Redis
  │     │                 └─► SMEMBERS / SINTER
  │     └─► sam_populate_from_gti(source_id, rows)
  │
  └─► [fallback path] full edge scan from nanch.edges
```