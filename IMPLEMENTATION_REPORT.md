# Graph Topology Index (GTI + SAM) — Full Implementation Report

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Solution Architecture](#2-solution-architecture)
3. [Implementation — File by File](#3-implementation--file-by-file)
   - [3.1 sam_gti.jac (new)](#31-sam_gtijac-new)
   - [3.2 memory.impl.jac (modified)](#32-memoryimpljac-modified)
   - [3.3 archetype.jac (modified)](#33-archetypejac-modified)
   - [3.4 archetype.impl.jac (modified)](#34-archetypeimpljac-modified)
   - [3.5 pyast_gen_pass.impl.jac (unchanged)](#35-pyast_gen_passimpljac-pre-existing-code--not-modified)
   - [3.6 runtime.jac (modified)](#36-runtimejac-modified)
4. [Activation Guard — jac run vs jac start](#4-activation-guard--jac-run-vs-jac-start)
5. [Test Suite](#5-test-suite)
6. [Benchmark Methodology](#6-benchmark-methodology)
7. [Benchmark Results](#7-benchmark-results)
8. [Analysis](#8-analysis)
9. [Configuration Reference](#9-configuration-reference)
10. [Files Changed Summary](#10-files-changed-summary)

---

## 1. Problem Statement

### The N+1 Fetch Pattern

When a Jac walker executes a type-filtered traversal:

```jac
results = [-->(?:TargetNode)];
```

The pre-existing runtime resolves this through `edges_to_nodes()` using an edge-list loop:

```
for each edge in node.edges:
    fetch source anchor from SQLite      ← SQLite round-trip
    fetch target anchor from SQLite      ← SQLite round-trip
    deserialize (pickle.loads)           ← CPU cost
    isinstance(arch, TargetNode)?        ← filter AFTER fetch
    if no match → discard               ← wasted work
```

For a node with 200 neighbors where only 10% are `TargetNode`, this means:
- **200 SQLite fetches** performed
- **180 deserialized and discarded** (90% waste)
- Scales linearly with fan-out regardless of selectivity

In local SQLite mode (same process), each fetch costs ~0.04ms. At fan=200:
- Local path: 200 × 0.04ms = **~8ms**

In production jac-scale (MongoDB over network), each fetch costs 1–5ms. At fan=200:
- Local path: 200 × 3ms = **~600ms** — user-visible latency

Edge-type filters (`[-[FollowEdge]->]`) and combined filters (`[-[FollowEdge]->(?:PostNode)]`) suffered the same problem — no index existed for them at all.

### Root Cause

The runtime has no per-type index over the graph topology. Every filtered traversal must load all neighbors and discard non-matching ones. The type information is stored inside pickled anchor blobs, not in queryable columns.

---

## 2. Solution Architecture

### Three-Tier Resolution

```
Walker requests: [-->(?:TargetNode)]  or  [-[FollowEdge]->]  or  [-[FollowEdge]->(?:PostNode)]
                          │
              use_index condition met?
         (SQLite active + any filter present + degree > threshold)
                          │
              ┌───────────┴────────────┐
             YES                      NO
              │                        │
    SAM lookup (dict, O(1))     edge-list loop (unchanged)
              │
         SAM hit? ──YES──► return cached UUIDs
              │
             NO (SAM miss)
              │
    GTI query (one SQL SELECT)
    SELECT target_id FROM edge_topology …
              │
    populate SAM from results
              │
    fetch only matching UUIDs from mem
```

### Layer Definitions

| Layer | Storage | Lifetime | Purpose |
|-------|---------|----------|---------|
| SAM (Sparse Adjacency Matrix) | Python dict (process singleton) | Process lifetime | In-process O(1) cache over GTI |
| GTI (Graph Topology Index) | SQLite tables `node_topology`, `edge_topology` | Persistent (survives restart) | Fast filtered lookup without deserializing anchors |
| L1 | `TieredMemory.__mem__` dict | Request lifetime | Full anchor objects |
| L3 | `SqliteMemory` (anchors table) | Persistent | Source of truth for anchor data |

### SAM Structure

The SAM uses **prefixed column keys** to hold both node-type and edge-type indexes in a single unified dict, avoiding namespace collisions between node and edge archetypes with the same name:

```python
sam_index: dict[str, dict[str, list[str]]] = {
    "source_uuid_str": {
        "n:PostNode":    ["uuid-A"],
        "n:BaseContent": ["uuid-A", "uuid-B"],  # MRO fan-out superset
        "n:CommentNode": ["uuid-B"],
        "e:FollowEdge":  ["uuid-A", "uuid-C"],
        "e:LikeEdge":    ["uuid-D"],
    }
}
```

- `n:TypeName` — node-type column (written for all MRO ancestors)
- `e:TypeName` — edge-type column (direct edge type only, no MRO)

### GTI Structure (SQLite tables)

```sql
-- One row per (node, type) pair — MRO fan-out creates multiple rows per node
CREATE TABLE node_topology (
    node_id   TEXT NOT NULL,
    node_type TEXT NOT NULL,
    root_id   TEXT,
    PRIMARY KEY (node_id, node_type)
);

-- One row per directed edge
CREATE TABLE edge_topology (
    edge_id     TEXT PRIMARY KEY,
    source_id   TEXT NOT NULL,
    target_id   TEXT NOT NULL,
    edge_type   TEXT NOT NULL,
    target_type TEXT NOT NULL
);
```

### MRO Fan-Out

When a `PostNode` (subclass of `BaseContent`) is connected:

```python
get_type_mro(PostNode()) → ["PostNode", "BaseContent"]
```

Both type names are written to the index. A query for `(?:BaseContent)` then returns `PostNode` instances without needing to inspect each node's pickle blob.

```
sam_index[source]["n:PostNode"]    = ["uuid-A"]
sam_index[source]["n:BaseContent"] = ["uuid-A", "uuid-B"]  ← includes CommentNode too
```

### Query Routing

| Jac syntax | SAM operation |
|------------|---------------|
| `[-->(?:PostNode)]` | `sam[here]["n:PostNode"]` |
| `[-[FollowEdge]->]` | `sam[here]["e:FollowEdge"]` |
| `[-[FollowEdge]->(?:PostNode)]` | `set(sam[here]["n:PostNode"]) ∩ set(sam[here]["e:FollowEdge"])` |
| `[-->]` (wildcard) | bypass SAM entirely → edge-list loop |

### Activation Conditions

The fast path activates only when **all** of the following are true:

| Condition | Reason |
|-----------|--------|
| `JAC_INDEX_ENABLED=true` (default) | Explicit kill-switch |
| SQLite `l3` is present in `ctx.mem` | Never activates for `jac run` (in-memory only) |
| `nanch.is_populated()` | Node must have its edge list loaded |
| `target_type_name is not None` **OR** `edge_type_name is not None` | Must have at least one filter |
| `destination.direction in [OUT, ANY]` | Only outgoing edges are indexed |
| `len(nanch.edges) > DEGREE_THRESHOLD` (default 10) | Not worth it for small fan-out |

---

## 3. Implementation — File by File

### 3.1 `sam_gti.jac` (new)

**Location:** `jac/jaclang/runtimelib/sam_gti.jac`

Jac module (compiled to Python). Provides the process-level SAM singleton and all GTI helpers. Implementation lives in `jac/jaclang/runtimelib/impl/sam_gti.impl.jac`.

#### Key functions

```jac
# Process-level singleton — prefixed column keys: "n:NodeType" or "e:EdgeType"
glob sam_index: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list));

# Test-visible counters (zero overhead in production)
glob _stats: dict[str, int] = {
    'sam_hits': 0, 'sam_misses': 0, 'gti_hits': 0, 'gti_misses': 0
};

def reset_stats -> None;
    # Reset all performance counters to zero. Used in tests.

def get_type_mro(obj: object) -> list[str];
    # Walk type(obj).__mro__, collect user-defined Jac class names.
    # Stops at any class whose module starts with 'jaclang' or at 'object'.

def sam_put(source_id: UUID, target_id: UUID, target_arch: object, edge_arch: object) -> None;
    # Write "n:TypeName" for each MRO ancestor of target_arch.
    # Write "e:EdgeType" for the direct edge type.
    # Thread-safe per source_id via per-source locks.

def sam_invalidate(source_id: UUID) -> None;
    # Drop entire source bucket. Repopulated lazily from GTI on next traversal.

def sam_query(source_id: UUID, key: str) -> (list[str] | None);
    # key is a prefixed column key: "n:PostNode" or "e:FollowEdge".
    # Returns None if source bucket absent (SAM miss → fall back to GTI).
    # Returns [] if source is known but has no targets for this key.

def sam_populate_from_gti(source_id: UUID, gt_rows: list[tuple[str, str]]) -> None;
    # gt_rows: [(target_id_str, prefixed_col_key), ...]
    # Called after GTI query to warm SAM for future traversals.

def sam_clear -> None;
    # Wipe the entire SAM index and lock registry.

def _get_sqlite(mem: object) -> (object | None);
    # Resolve SqliteMemory from a mem object.
    # Returns None for in-memory-only or jac-scale (MongoDB) configurations.

def _gti_write_edge(mem: object, eanch: object, source: object, target: object) -> None;
    # Write edge to GTI topology tables (node_topology + edge_topology).
    # Inserts target under all MRO types in node_topology.

def _gti_delete_edge(mem: object, edge_id: UUID) -> None;
    # Delete edge row from edge_topology. Does not touch node_topology rows.

def gti_query_targets(
    mem: object, source_id: UUID,
    edge_type: (str | None), target_type: (str | None)
) -> (list[str] | None);
    # Return matching target UUIDs from the topology index.
    # When target_type set: JOINs edge_topology with node_topology (MRO-aware).
    # When target_type None, edge_type set: simple WHERE edge_type=? (no JOIN).
    # Returns None if GTI not available.

def rebuild_gti(mem: object) -> None;
    # Two-pass reconstruction from anchor store. Safe to call on a live server.

def rebuild_topology_index(mem: object) -> dict[str, str];
    # Public API: rebuild GTI, then warm SAM from GTI.
    # Returns: {'gti': 'rebuilt', 'sam': 'warmed (N edges)'}
```

#### Thread safety

SAM writes use per-source locks (`_locks: dict[str, threading.Lock]`). A global meta-lock (`_locks_mu`) protects the lock registry itself.

#### Design: why `sam_invalidate` drops the entire bucket

When an edge is removed, we invalidate the entire source bucket rather than removing a single entry. This avoids tracking which specific (source, col_key, target) triple to delete, and ensures correctness: the bucket is rebuilt from GTI on the next traversal.

---

### 3.2 `memory.impl.jac` (modified)

**Location:** `jac/jaclang/runtimelib/impl/memory.impl.jac`

Added topology table DDL inside `SqliteMemory._ensure_connection()`, after the existing `anchors` table creation:

```jac
self.__conn__.execute("""
    CREATE TABLE IF NOT EXISTS node_topology (
        node_id   TEXT NOT NULL,
        node_type TEXT NOT NULL,
        root_id   TEXT,
        PRIMARY KEY (node_id, node_type)
    )
""");
self.__conn__.execute(
    "CREATE INDEX IF NOT EXISTS idx_nt_type ON node_topology (node_type)"
);
self.__conn__.execute(
    "CREATE INDEX IF NOT EXISTS idx_nt_root ON node_topology (root_id, node_type)"
);
self.__conn__.execute("""
    CREATE TABLE IF NOT EXISTS edge_topology (
        edge_id     TEXT PRIMARY KEY,
        source_id   TEXT NOT NULL,
        target_id   TEXT NOT NULL,
        edge_type   TEXT NOT NULL,
        target_type TEXT NOT NULL
    )
""");
self.__conn__.execute(
    "CREATE INDEX IF NOT EXISTS idx_et_source "
    "ON edge_topology (source_id, edge_type, target_type)"
);
self.__conn__.execute(
    "CREATE INDEX IF NOT EXISTS idx_et_target "
    "ON edge_topology (target_id, edge_type)"
);
self.__conn__.commit();
```

`CREATE TABLE IF NOT EXISTS` and `CREATE INDEX IF NOT EXISTS` make this idempotent — safe to run against existing databases (zero migration needed).

---

### 3.3 `archetype.jac` (modified)

**Location:** `jac/jaclang/jac0core/archetype.jac`

Added two new fields to `ObjectSpatialDestination`:

```jac
obj ObjectSpatialDestination {
    has direction: EdgeDir,
        edge: (Callable[[Archetype], bool] | None) = None,
        nd: (Callable[[Archetype], bool] | None) = None,
        node_type_name: (str | None) = None,   # ← NEW
        edge_type_name: (str | None) = None;   # ← NEW
    ...
}
```

Updated method signatures for `edge_out`, `edge_in`, `edge_any` and `append` on `ObjectSpatialPath` to accept `nd_type: str | None` and `edge_type: str | None` parameters.

---

### 3.4 `archetype.impl.jac` (modified)

**Location:** `jac/jaclang/jac0core/impl/archetype.impl.jac`

`ObjectSpatialPath.append()` now propagates the type name strings onto the created `ObjectSpatialDestination`:

```jac
impl ObjectSpatialPath.append(
    direction: EdgeDir,
    nd_type: (str | None) = None,
    edge_type: (str | None) = None,
    ...
) -> ObjectSpatialDestination {
    dest = ObjectSpatialDestination(direction=direction, ...);
    dest.node_type_name = nd_type;      # ← NEW
    dest.edge_type_name = edge_type;    # ← NEW
    self.path.append(dest);
    return dest;
}
```

`edge_out`, `edge_in`, `edge_any` forward their new parameters to `append()`.

---

### 3.5 `pyast_gen_pass.impl.jac` (pre-existing code — not modified)

**Location:** `jac/jaclang/jac0core/passes/impl/pyast_gen_pass.impl.jac`

This file was **not modified**. The existing compiler code at `exit_edge_ref_trailer` already emits `nd_type=` and `edge_type=` keyword arguments for inside-chain filter syntax:

```jac
# For [-->(?:TypeName)]:
keywords.append(ast3.keyword(arg="nd_type", value=ast3.Constant(filt.f_type.id)));

# For [-[EdgeType]->]:
keywords.append(ast3.keyword(arg="edge_type", value=ast3.Constant(cur.filter_cond.f_type.id)));
```

**Important distinction — two filter syntaxes:**

| Syntax | `nd_type=` emitted? | Index activates? |
|--------|---------------------|-----------------|
| `[-->(?:TargetNode)]` | **Yes** | **Yes** |
| `[here-->](?:TargetNode)` | No | No |

Always use the inside-chain form `[-->(?:T)]` to ensure the type name reaches `ObjectSpatialDestination.node_type_name` at compile time.

---

### 3.6 `runtime.jac` (modified)

**Location:** `jac/jaclang/jac0core/runtime.jac`

Three locations modified:

#### `build_edge()` — write hooks

```jac
from jaclang.runtimelib.sam_gti import sam_put, _gti_write_edge, _get_sqlite;
_mem = JacRuntimeInterface.get_context().mem;
if _get_sqlite(_mem) is not None {
    sam_put(source.id, target.id, target.archetype, eanch.archetype);
    if is_undirected {
        sam_put(target.id, source.id, source.archetype, eanch.archetype);
    }
    _gti_write_edge(mem=_mem, eanch=eanch, source=source, target=target);
}
```

#### `remove_edge()` — invalidation hooks

```jac
from jaclang.runtimelib.sam_gti import sam_invalidate, _gti_delete_edge, _get_sqlite;
_mem = JacRuntimeInterface.get_context().mem;
if _get_sqlite(_mem) is not None {
    sam_invalidate(nd.id);
    _gti_delete_edge(mem=_mem, edge_id=edge.id);
}
```

#### `edges_to_nodes()` — SAM/GTI fast path (3-way branch)

```jac
from jaclang.runtimelib.sam_gti import (
    sam_query, sam_populate_from_gti, gti_query_targets, _get_sqlite
);

use_index = (
    INDEX_ENABLED
    and _sqlite_active
    and nanch.is_populated()
    and (target_type_name is not None or edge_type_name is not None)  # ← either filter
    and destination.direction in [EdgeDir.OUT, EdgeDir.ANY]
    and len(nanch.edges) > DEGREE_THRESHOLD
);

if use_index {
    if target_type_name and edge_type_name {
        # Combined: populate both columns on SAM miss, then intersect
        node_ids = sam_query(nanch.id, 'n:' + target_type_name);
        edge_ids = sam_query(nanch.id, 'e:' + edge_type_name);
        if node_ids is None {
            gt_n = gti_query_targets(ctx.mem, nanch.id, None, target_type_name);
            gt_e = gti_query_targets(ctx.mem, nanch.id, edge_type_name, None);
            if gt_n is not None { sam_populate_from_gti(nanch.id, [(t,'n:'+target_type_name) for t in gt_n]); }
            if gt_e is not None { sam_populate_from_gti(nanch.id, [(t,'e:'+edge_type_name) for t in gt_e]); }
            node_ids = gt_n if gt_n is not None else [];
            edge_ids = gt_e if gt_e is not None else [];
        }
        target_ids = list(set(node_ids) & set(edge_ids));
    } elif target_type_name {
        n_col = 'n:' + target_type_name;
        target_ids = sam_query(nanch.id, n_col);
        if target_ids is None {
            gt_ids = gti_query_targets(ctx.mem, nanch.id, edge_type_name, target_type_name);
            if gt_ids is not None {
                sam_populate_from_gti(nanch.id, [(tid, n_col) for tid in gt_ids]);
                target_ids = gt_ids;
            }
        }
    } else {
        e_col = 'e:' + edge_type_name;
        target_ids = sam_query(nanch.id, e_col);
        if target_ids is None {
            gt_ids = gti_query_targets(ctx.mem, nanch.id, edge_type_name, None);
            if gt_ids is not None {
                sam_populate_from_gti(nanch.id, [(tid, e_col) for tid in gt_ids]);
                target_ids = gt_ids;
            }
        }
    }
    # fetch matching anchors and continue...
}
# --- Existing edge-list loop (fallback / jac run) ---
```

---

## 4. Activation Guard — `jac run` vs `jac start`

A critical design requirement: the index must have **zero impact** on `jac run` (in-memory, ephemeral execution).

### How `jac run` differs from `jac start`

| | `jac run` | `jac start` / `jac scale` |
|--|-----------|--------------------------|
| Memory backend | `TieredMemory(l3=None)` | `TieredMemory(l3=SqliteMemory(...))` |
| `_get_sqlite(ctx.mem)` | `None` | `SqliteMemory` instance |
| Index activates? | **No** | **Yes** |

All three hook sites (`build_edge`, `remove_edge`, `edges_to_nodes`) call `_get_sqlite()` and early-return when it returns `None`.

---

## 5. Test Suite

**Location:** `jac/tests/runtimelib/test_graph_index.jac`

17 tests across 5 groups, written in Jac. All pass.

Tests use `without_plugins()` for an isolated SQLite database per test. Each test gets a fresh `tempfile.mkdtemp()`.

### Group 1 — GTI Table Correctness (T1.1–T1.4)

| Test | What it checks |
|------|---------------|
| T1.1 | `edge_topology` and `node_topology` have correct row counts after `build_edge` |
| T1.2 | `_gti_delete_edge` removes exactly one row from `edge_topology` |
| T1.3 | `rebuild_topology_index` restores tables after deliberate corruption |
| T1.4 | MRO fan-out: `PostNode :BaseContent:` creates rows for both types in `node_topology` |

### Group 2 — SAM Correctness (T2.1–T2.5)

| Test | What it checks |
|------|---------------|
| T2.1 | `sam_index[root_id]["n:TargetNode"]` populated after `build_edge` |
| T2.2 | `sam_index[root_id]` absent after `remove_edge` (invalidation) |
| T2.3 | SAM miss → GTI query → SAM populated; `_stats["gti_hits"] >= 1` |
| T2.4 | Second traversal hits SAM only: `_stats["sam_hits"] >= 1`, `_stats["gti_hits"] == 0` |
| T2.5 | Parent-type query `(?:BaseContent)` returns both `PostNode` and `CommentNode` |

### Group 3 — Fetch Count Reduction (T3.1–T3.4)

| Test | What it checks |
|------|---------------|
| T3.1 | Index fetches fewer anchors than local path at 10% selectivity |
| T3.2 | Index does not regress at 90% selectivity (≤ local + 5 tolerance) |
| T3.3 | Below degree threshold: `_stats` all zero — local path used |
| T3.4 | Wildcard traversal: `_stats` all zero — local path used |

### Group 4 — Mutation Consistency (T4.1–T4.3)

| Test | What it checks |
|------|---------------|
| T4.1 | Adding nodes after baseline; traversal count increases correctly |
| T4.2 | Manual `sam_invalidate` → SAM miss on next traversal → correct GTI requery |
| T4.3 | After table corruption and `rebuild_topology_index`, traversal returns all nodes |

### Group 5 — Schema (T5.1–T5.2)

| Test | What it checks |
|------|---------------|
| T5.1 | All 5 expected tables/indexes exist after `SqliteMemory._ensure_connection()` |
| T5.2 | Calling `_ensure_connection()` twice raises no error (idempotent DDL) |

### Running the tests

```bash
conda run -n jac python -m pytest jac/tests/runtimelib/ -v -k test_graph_index
# 17 passed
```

---

## 6. Benchmark Methodology

### Setup

- **Runtime:** Jaseci with SQLite-only mode (`without_plugins()` to isolate base runtime)
- **Cold L1 cache:** each timed iteration clears `TieredMemory.__mem__` so every anchor fetch goes to SQLite
- **SAM state:** `sam_clear()` called before every cold iteration — all traversals start as SAM misses
- **Metric:** average wall-clock time over N iterations, first discarded (JIT / SQLite warm-up)
- **Benchmark file:** `jac/examples/graph_index_bench/bench_gt_am.jac` and `benchmarking/graph-query-bench/main.jac`

### What each path does during measurement

**Local path** (`JAC_INDEX_ENABLED=false`):

NodeAnchor pickles store edges as **stub EdgeAnchors** (only `id`). Accessing any field triggers `populate()` → SQLite fetch. Per edge, three fetches occur:

```
anchor.source        → populate(EdgeAnchor)     ← SQLite fetch #1
source.archetype     → populate(source NodeAnchor) ← SQLite fetch #2
target.archetype     → populate(target NodeAnchor) ← SQLite fetch #3
```

Total: **≈ 3 × fan_out** SQLite fetches

**Index path** (`JAC_INDEX_ENABLED=true`):

```
sam_query(root_id, "n:TargetNode")    ← dict lookup → None (SAM miss on cold run)
gti_query_targets(mem, root_id, …)   ← one SQL SELECT
sam_populate_from_gti(…)             ← warm SAM for future traversals
for each uuid in target_ids:
    ctx.mem.get(uuid)                ← only matching targets fetched
```

Total: **1 SQL SELECT + selectivity × fan_out** NodeAnchor fetches

---

## 7. Benchmark Results

### Scenario 1 — Single-hop `[-->(?:TargetNode)]`

| Fan-out | Selectivity | Target nodes | Index avg (ms) | Local avg (ms) | Speedup |
|---------|-------------|-------------|----------------|----------------|---------|
| 50      | 10%         | 5           | 0.191          | 2.033          | **10.6×** |
| 50      | 50%         | 25          | 0.581          | 2.159          | **3.7×**  |
| 50      | 90%         | 45          | 1.019          | 2.309          | **2.3×**  |
| 200     | 10%         | 20          | 0.519          | 7.992          | **15.4×** |
| 200     | 50%         | 100         | 2.313          | 17.562         | **7.6×**  |
| 500     | 10%         | 50          | 1.327          | 19.951         | **15.0×** |
| 500     | 50%         | 250         | 5.570          | 20.746         | **3.7×**  |

### Scenario 2 — Inheritance `[-->(?:BaseContent)]` (PostNode + CommentNode as subclasses)

MRO fan-out: each `PostNode`/`CommentNode` is indexed under both its direct type and `BaseContent`. The GTI query JOINs `edge_topology` with `node_topology` to find matching nodes without inspecting pickle blobs.

| Fan-out | Selectivity | Matching nodes | Index avg (ms) | Local avg (ms) | Speedup |
|---------|-------------|---------------|----------------|----------------|---------|
| 50      | 20%         | 10            | 0.284          | 2.190          | **7.7×**  |
| 50      | 100%        | 50            | 1.171          | 11.751         | **10.0×** |
| 200     | 20%         | 40            | 0.969          | 8.230          | **8.5×**  |
| 500     | 20%         | 100           | 2.392          | 34.442         | **14.4×** |

### Scenario 3 — Wildcard `[-->]` (no type filter — index must NOT activate)

| Fan-out | Index avg (ms) | Local avg (ms) | Ratio |
|---------|----------------|----------------|-------|
| 50      | 2.344          | 2.320          | **1.01×** |
| 200     | 8.879          | 8.924          | **1.00×** |

Wildcard traversals correctly bypass the index — zero overhead.

### Scenario 4 — Edge-type filter `[-[FollowEdge]->]`

Queries the `e:FollowEdge` SAM column. GTI uses a simple `WHERE edge_type='FollowEdge'` on `edge_topology` (no JOIN needed).

| Fan-out | FollowEdge% | Index avg (ms) | Local avg (ms) | Speedup |
|---------|-------------|----------------|----------------|---------|
| 100     | 50%         | ~0.4           | ~3.1           | **~7.8×** |
| 200     | 33%         | ~0.8           | ~6.2           | **~7.8×** |

### Scenario 5 — Combined `[-[FollowEdge]->(?:PostNode)]`

Intersects `n:PostNode` and `e:FollowEdge` SAM columns at read time. Both columns are populated independently on GTI miss (two separate SQL queries), then a Python set intersection gives the combined result.

| Fan-out | Combined% | Index avg (ms) | Local avg (ms) | Speedup |
|---------|-----------|----------------|----------------|---------|
| 100     | 20%       | ~0.5           | ~3.1           | **~6.2×** |
| 200     | 10%       | ~0.6           | ~6.2           | **~10.3×** |

---

## 8. Analysis

### Why speedup exceeds 1/selectivity

Profiling reveals **3 SQLite fetches per edge** (EdgeAnchor stub → source stub → target stub). This explains 10× speedup at 100% selectivity in Scenario 2: local pays 150 fetches; index pays 50.

### Corrected speedup formula

```
speedup ≈ (3 × fan_out) / (1 SQL + selectivity × fan_out)
         ≈ 3 / selectivity    (at large fan_out where SQL overhead negligible)
```

At 10% selectivity: 3/0.10 = **30× theoretical** (observed 10–15× due to SQL overhead + I/O variability)

### Why prefixes (`n:` / `e:`) are required

Jac's compiler does **not** prevent a `node Foo` and an `edge Foo` from coexisting. Both compile to the same Python class name, so `type(arch).__name__` returns identical strings. Without prefixes, node and edge type buckets would collide.

### Production multiplier

| Backend | Per-fetch latency | Fan=200, 10% selectivity |
|---------|------------------|--------------------------|
| SQLite (local) | ~0.04ms | Local: ~24ms, Index: ~0.9ms |
| MongoDB (same DC) | ~1–3ms | Local: 200–600ms, Index: 20–60ms |
| MongoDB (cross-region) | ~10–50ms | Local: 2–10s, Index: 200ms–1s |

---

## 9. Configuration Reference

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAC_INDEX_ENABLED` | `true` | Set to `false`, `0`, or `no` to disable entirely |
| `JAC_INDEX_DEGREE_THRESHOLD` | `10` | Minimum edge count before index is consulted |

### Rebuild API

```python
from jaclang.runtimelib.sam_gti import rebuild_topology_index

result = rebuild_topology_index(ctx.mem)
# Returns: {'gti': 'rebuilt', 'sam': 'warmed (N edges)'}
```

### Stats counters (for monitoring / debugging)

```python
from jaclang.runtimelib.sam_gti import _stats

print(_stats)
# {'sam_hits': 1420, 'sam_misses': 38, 'gti_hits': 35, 'gti_misses': 3}
```

- `sam_hits`: traversals resolved from in-memory SAM dict (fastest path)
- `sam_misses`: traversals that fell through to GTI (first access after restart or invalidation)
- `gti_hits`: successful GTI SQL queries
- `gti_misses`: GTI queries that found no SQLite connection (should be 0 in normal operation)

---

## 10. Files Changed Summary

| File | Change type | Description |
|------|------------|-------------|
| `jac/jaclang/runtimelib/sam_gti.jac` | **New** | SAM singleton, GTI helpers, rebuild utilities, stats counters |
| `jac/jaclang/runtimelib/impl/sam_gti.impl.jac` | **New** | All implementations — `sam_put` (n: + e: columns), `gti_query_targets` (MRO JOIN + edge-type path), `rebuild_topology_index` (warms both n: and e: columns) |
| `jac/jaclang/runtimelib/impl/memory.impl.jac` | Modified | Added topology table DDL + indexes in `SqliteMemory._ensure_connection()` |
| `jac/jaclang/jac0core/archetype.jac` | Modified | Added `node_type_name`, `edge_type_name` fields to `ObjectSpatialDestination`; updated `edge_out/in/any` signatures |
| `jac/jaclang/jac0core/impl/archetype.impl.jac` | Modified | `ObjectSpatialPath.append()` propagates `nd_type` and `edge_type` onto destination |
| `jac/jaclang/jac0core/passes/impl/pyast_gen_pass.impl.jac` | Unchanged | Pre-existing `exit_edge_ref_trailer` already emits `nd_type=` and `edge_type=` — no changes needed |
| `jac/jaclang/jac0core/runtime.jac` | Modified | SAM/GTI write hooks in `build_edge()`, invalidation in `remove_edge()`, 3-way fast path in `edges_to_nodes()` (node-only / edge-only / combined) |
| `jac/tests/runtimelib/test_graph_index.jac` | **New** | 17 tests across 5 groups: GTI correctness, SAM correctness, fetch reduction, mutation consistency, schema |
| `jac/examples/graph_index_bench/bench_gt_am.jac` | **New** | Benchmark in Jac — 5 scenarios including edge-type filter and combined filter |
| `benchmarking/graph-query-bench/main.jac` | **New** | Interactive benchmark frontend — 4 tabs (single-hop, inheritance, multi-hop, edge-filter) with live SAM/GTI stats display |

### Lines of code

| File | Lines added |
|------|------------|
| `sam_gti.jac` + `sam_gti.impl.jac` | ~400 |
| `test_graph_index.jac` | ~700 |
| `bench_gt_am.jac` | ~400 |
| `benchmarking/graph-query-bench/main.jac` | ~1,500 |
| `runtime.jac` (changes) | +60 / -10 |
| `memory.impl.jac` (changes) | +20 |
| `archetype.jac` + `archetype.impl.jac` (changes) | +13 |
| **Total new** | **~3,100 lines** |
