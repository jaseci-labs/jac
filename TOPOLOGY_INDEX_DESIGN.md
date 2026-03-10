# Topology Index — Current State & Unified Matrix Extension

## Naming Convention

| Name | Full Name | Role |
|------|-----------|------|
| **GTI** | Graph Topology Index | Persistent, SQLite-backed backing store — the authoritative record of graph topology |
| **SAM** | Sparse Adjacency Matrix | In-process materialization of the matrix — volatile cache over GTI |

The SAM is the actual matrix structure. The GTI is the normalized relational store the SAM is reconstructed from on a cold miss.

---

## 1. What We Have Now

### The Problem

A type-filtered walker traversal like `[-->(?:PostNode)]` used to require loading and deserializing every neighbor anchor from SQLite, then discarding non-matching ones:

```
for each of 500 edges:
    fetch anchor from SQLite    ← always
    deserialize (pickle.loads)  ← always
    isinstance(arch, PostNode)? ← filter AFTER fetch
    if no match → discard       ← 450 wasted fetches at 10% selectivity
```

### The Current Solution — Two Layers

**GTI (Graph Topology Index) — Persistent, SQLite-backed**

Two tables stored alongside the main `anchors` table:

```sql
node_topology (node_id, node_type, root_id)
-- One row per (node, type) pair — MRO fan-out creates multiple rows per node
-- e.g. PostNode instance gets rows for 'PostNode' AND 'BaseContent'

edge_topology (edge_id, source_id, target_id, edge_type, target_type)
-- One row per directed edge, direct type only (no MRO in this table)
```

**SAM (Sparse Adjacency Matrix) — Volatile, Python dict**

```python
sam_index[source_id_str][target_type_str] = [target_id_str, ...]
```

Populated lazily on first GTI query for a source node. Survives for the lifetime of the process.

### How a Traversal Resolves

```
[-->(?:PostNode)] on node with fan-out 500
         │
    use_index? (SQLite active + node_type_name set + degree > threshold)
         │
        YES
         │
    sam_query(source_id, "PostNode")
         │
    ┌────┴────────────────────────┐
  SAM hit                      SAM miss
  (µs dict lookup)          (first access)
    │                             │
    │                    gti_query_targets()
    │                    SELECT DISTINCT et.target_id
    │                    FROM edge_topology et
    │                    JOIN node_topology nt ON et.target_id = nt.node_id
    │                    WHERE et.source_id=? AND nt.node_type='PostNode'
    │                             │
    │                    populate SAM from results
    │                             │
    └─────────────┬───────────────┘
                  │
         for each matching UUID:
             ctx.mem.get(uuid)   ← only matching nodes fetched
```

### What the SAM Covers (Unified — Implemented)

The SAM uses **prefixed column keys** covering both node types and edge types:

```
sam_index[source_id] = {
    "n:PostNode":    [uuid1, uuid2],
    "n:BaseContent": [uuid1, uuid2, uuid3, uuid4],   ← MRO superset
    "n:CommentNode": [uuid3, uuid4],
    "e:FollowEdge":  [uuid1, uuid3],
    "e:LikeEdge":    [uuid5],
}
```

Edge-type queries (`[-[FollowEdge]->]`) hit `"e:FollowEdge"`. Combined queries intersect both columns in O(min(a,b)). The `use_index` guard activates when either `target_type_name` or `edge_type_name` is set.

### Benchmark Results (Current Implementation)

| Scenario | Fan-out | Selectivity | Speedup |
|----------|---------|-------------|---------|
| Node type filter | 500 | 10% | **16.3×** |
| Node type filter | 200 | 10% | **15.6×** |
| Inheritance (MRO) | 500 | 20% | **10.2×** |
| Wildcard (no filter) | any | 100% | **1.0×** (correctly bypassed) |

---

## 2. The New Idea — Unified Type-Keyed SAM

### The Mental Model

Extend the SAM into a full **sparse adjacency matrix** where:

- **Rows** = source node instance IDs
- **Columns** = all filter keys: node types + edge types (unified namespace)
- **Cell** = list of target node IDs reachable from that source matching that filter

```
source_id  │ n:PostNode  │ n:BaseContent     │ e:FollowEdge │ e:LikeEdge
───────────┼─────────────┼───────────────────┼──────────────┼───────────
user_1     │ [p1, p2]    │ [p1, p2, c1, c2]  │ [u2, u3]     │ [p1]
user_2     │ [p3]        │ [p3]              │ [u1]          │ [p2, p3]
root_id    │ []          │ []                │ [user_1]      │ []
```

Prefix convention to avoid namespace collision:
- `n:TypeName` — node type column
- `e:TypeName` — edge type column

### Walker Query → SAM Lookup

| Jac syntax | SAM operation |
|------------|---------------|
| `[-->(?:PostNode)]` | `sam[here]["n:PostNode"]` |
| `[-[FollowEdge]->]` | `sam[here]["e:FollowEdge"]` |
| `[-[FollowEdge]->(?:PostNode)]` | `intersect(sam[here]["e:FollowEdge"], sam[here]["n:PostNode"])` |
| `[-->]` (wildcard) | bypass SAM entirely → edge-list loop |

### Why Intersection for Combined Filters

For `-[FollowEdge]->(?:PostNode)`, two design options:

**Option A — Composite column key** (`"e:FollowEdge+n:PostNode"`):
- Write cost: O(edge_types × node_types) per edge — combinatorial
- Read cost: O(1) direct lookup
- Problem: column space explodes with schema size

**Option B — Intersection at read time** (preferred):
- Write cost: same as current — one node-type column + one edge-type column per edge
- Read cost: one set intersection of two small lists (~microseconds)
- Column space: bounded by `|node_types| + |edge_types|`

```python
# Combined filter — intersection at read time
node_ids = sam[source]["n:PostNode"]    # e.g. [p1, p2, p5, p8]
edge_ids = sam[source]["e:FollowEdge"]  # e.g. [p1, p3, p5, u2]
result   = set(node_ids) & set(edge_ids)   # → [p1, p5]
```

### What Changes from Current Implementation

**Writes (`sam_put` + `_gti_write_edge`):**

Currently `sam_put` writes only node-type columns. Extension adds edge-type column:

```python
# Current: node type only
for type_name in get_type_mro(target_arch):          # e.g. ["PostNode", "BaseContent"]
    sam_index[source]["n:" + type_name].append(target_id)

# Extended: also write edge type column
edge_type_name = type(edge_arch).__name__             # e.g. "FollowEdge"
sam_index[source]["e:" + edge_type_name].append(target_id)
```

GTI `edge_topology` already stores `edge_type` — no SQL schema change needed.

**Reads (`sam_query` + `use_index` guard):**

Currently `use_index` requires `target_type_name is not None`. Extension:

```python
use_index = (
    INDEX_ENABLED
    and _sqlite_active
    and nanch.is_populated()
    and (target_type_name is not None or edge_type_name is not None)  # ← either filter
    and destination.direction in [OUT, ANY]
    and len(nanch.edges) > DEGREE_THRESHOLD
)
```

Query logic:
```python
if target_type_name and edge_type_name:
    # Combined: intersect two columns
    node_ids = set(sam_query(source_id, "n:" + target_type_name) or [])
    edge_ids = set(sam_query(source_id, "e:" + edge_type_name) or [])
    target_ids = list(node_ids & edge_ids)
elif target_type_name:
    target_ids = sam_query(source_id, "n:" + target_type_name)
elif edge_type_name:
    target_ids = sam_query(source_id, "e:" + edge_type_name)
```

**GTI query (`gti_query_targets`):**

Edge-type-only path already works — it's a simple `WHERE edge_type=?` on `edge_topology`. No schema change. Only the SAM caching of the result is new.

### Properties of the Unified SAM

| Property | Value |
|----------|-------|
| Column space | `\|node_types\| + \|edge_types\|` — bounded, schema-defined |
| Sparsity | High — most cells empty for any given source node |
| MRO handling | Node-type columns only (edge types have no inheritance) |
| Write cost per edge | O(MRO depth + 1) — same as current plus one edge-type write |
| Read cost (warm) | O(1) dict lookup per column; O(min(a,b)) set intersection for combined |
| Invalidation | Unchanged — drop entire source row on any edge removal |
| Persistence | GTI already stores edge_type; SAM is still volatile cache over GTI |

### What the SAM Does NOT Replace

The SAM gives **target UUIDs** only. The final `ctx.mem.get(uuid)` fetch for each matching node is still required — the SAM eliminates wasted fetches on non-matching nodes, not the necessary fetches for matching ones.

```
SAM lookup:   O(1) or O(intersection)   → [uuid1, uuid2, uuid5]
Final fetch:  O(matching_count)         → deserialize only matching anchors
```

This is the fundamental speedup: `matching_count << fan_out` at low selectivity.

---

## 3. Summary of Changes — ✅ Implemented

All gaps from the original design have been closed.

| Component | Change | Status |
|-----------|--------|--------|
| `sam_put` | writes `e:EdgeType` column in addition to `n:NodeType` MRO columns | ✅ Done |
| `sam_query` | accepts any prefixed key `n:X` or `e:X` | ✅ Done |
| `use_index` guard | activates when `target_type_name or edge_type_name` | ✅ Done |
| `edges_to_nodes` | 3-way branch: node-only / edge-only / combined (set intersection) | ✅ Done |
| `gti_query_targets` | SAM is now populated from GTI results for both `n:` and `e:` columns | ✅ Done |
| GTI schema | no change needed — `edge_topology.edge_type` already existed | ✅ Confirmed |
| `sam_populate_from_gti` | accepts pre-prefixed `(target_id, col_key)` tuples | ✅ Done |
| Naming convention | `am_index` → `sam_gti`, all functions renamed SAM/GTI throughout | ✅ Done |
| Edge creation syntax | `+>: EdgeType() :+>` in build walkers | ✅ Done |
| Edge filter traversal | `[src ->:EdgeType:->]` and `[src ->:EdgeType:-> (?:NodeType)]` | ✅ Done |

No SQL schema changes were needed. No new tables. The unified SAM is a pure extension of the existing SAM key space.

### Files implementing the unified SAM

- `jac/jaclang/runtimelib/sam_gti.jac` — declarations
- `jac/jaclang/runtimelib/impl/sam_gti.impl.jac` — implementations
- `jac/jaclang/jac0core/runtime.jac` — 3-way fast path in `edges_to_nodes()`
- `jac/examples/graph_index_bench/bench_gt_am.jac` — Scenarios 4 & 5 benchmark
- `benchmarking/graph-query-bench/main.jac` — Edge Filter tab in interactive benchmark
