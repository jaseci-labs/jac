# Storage Optimization for Jac-Scale: Benchmarks, Findings, and Decisions

**Authors:** Jaseci Enterprise Team
**Date:** 2026-03-22
**Status:** In Progress

---

## 1. Problem Statement

Jac's tiered memory hierarchy (L1 in-process cache, L2 Redis, L3 MongoDB/SQLite) stores
graph anchors as opaque serialized blobs keyed by UUID. When a walker traverses edges
(`-->`, `-->(?:Type)`, `->:EdgeType:->`), the runtime iterates `node.edges` -- a list
of stub EdgeAnchors. Each stub's first attribute access triggers `populate()`, which calls
`mem.get(id)` -- a single database round-trip. For a node with N edges, this produces
2N+1 individual database fetches (1 origin + N edges + N targets).

This N+1 pattern is well-documented in database literature. It is the dominant latency
source for graph traversals in production jac-scale deployments where L3 is MongoDB
(1-10ms per round-trip).

---

## 2. Approach 1: Structured Metadata Columns (PR #5270 -- REJECTED)

### Hypothesis

Surface `anchor_type`, `archetype`, `source`, `target` as queryable columns/fields
alongside the serialized blob. This enables:
- SQL JOINs (SQLite) and aggregation pipelines (MongoDB) for edge traversal
- Indexed archetype lookups without deserializing blobs
- Filter push-down to the database

### Implementation

- **SQLite**: Added 4 columns + 3 partial indexes to the `anchors` table
- **MongoDB**: Added 4 top-level document fields + 3 indexes
- Auto-migration from v1 schema on first access
- All 12 CI checks passed

### Benchmark Method

Four Docker containers: v1/v2 × SQLite/MongoDB. Each runs `jac run benchmark.jac` --
a `.jac` program that builds a graph with `++>` and `+>:EdgeType:+>`, then traverses
with `-->`, `-->(?:PersonNode)`, `->:KnowsEdge:->`, and `->:KnowsEdge:->(?:PersonNode)`.
Walker abilities use `with Root entry` to trigger on the root node. Each operation runs
5 iterations. Timing via `time.perf_counter()`.

### Results

#### SQLite (local development)

| Metric | v1 (ms) | v2 (ms) | Change |
|--------|:---:|:---:|:---:|
| Build (100 nodes, 1K edges) | 1,240 | 1,188 | ~same |
| Build (500 nodes, 5K edges) | 3,476 | 5,645 | **+62%** |
| `-->` (100 results) | 4.0 | 3.1 | -22% |
| `-->(?:PersonNode)` (50) | 2.6 | 1.2 | -54% |
| `->:KnowsEdge:->` (10) | 0.6 | 0.7 | ~same |

#### MongoDB (jac-scale production)

| Metric | v1 (ms) | v2 (ms) | Change |
|--------|:---:|:---:|:---:|
| Build (100 nodes, 1K edges) | 2,714 | 7,588 | **+180%** |
| Build (500 nodes, 5K edges) | 8,773 | 78,948 | **+800%** |
| `-->` (600 results) | 14.6 | 21.0 | +44% |
| `->:KnowsEdge:->` (10) | 1.1 | 11.8 | **+970%** |

### Analysis

The structured metadata columns added significant write overhead:
- **SQLite**: Every `put()` extracts metadata + writes 6 columns instead of 2
- **MongoDB**: Larger documents (489 → 634 bytes) + 3 index updates per write

The traversal was also slower because:
- The runtime still uses the N+1 `populate()` path
- The metadata columns are not used during traversal -- only during direct database queries
- The indexes added overhead to every write but weren't queried by the walker engine

### Decision

**REJECTED.** The schema change adds cost at the storage layer (writes) without
changing the runtime traversal code path (reads). The optimized query capabilities
(aggregation pipelines, JOINs) exist but are unreachable through the standard
walker `-->` operators.

### Supplementary: Direct MongoDB Query Results

When bypassing the Jac runtime and querying MongoDB directly with pymongo:

| Operation | N+1 (ms) | Aggregation Pipeline (ms) | Speedup |
|-----------|:---:|:---:|:---:|
| Traversal (20 edges) | 26.8 | 3.1 | **8.5x** |
| Type-filtered (10 matches) | 29.9 | 5.4 | **5.5x** |
| Archetype lookup (250 matches) | 1,279 | 3.8 | **341x** |

These results confirm the structured approach works at the query level -- the
problem is wiring it into the runtime.

---

## 3. Approach 2: batch_get() -- Read-Path Only (In Progress)

### Hypothesis

Add a `batch_get(ids: list[UUID])` method to the Memory interface that fetches
multiple anchors in a single database query. Then prefetch all edge stubs + target
nodes before the filter loop in `edges_to_nodes()`. This:
- Changes only the read path (zero write overhead)
- Requires no schema changes
- Is transparent to Jac developers (same `-->` syntax)
- Uses `SELECT ... WHERE id IN (...)` (SQLite) and `find({_id: {$in: [...]}})` (MongoDB)

### Implementation

- **Memory interface**: `batch_get(ids)` added to MongoBackend, RedisBackend, ScaleTieredMemory
- **Runtime**: `_prefetch_edges(origin)` function calls `batch_get` before the filter loop
  in `get_edges()`, `get_edges_with_node()`, and `edges_to_nodes()`
- **SQLite**: Not modified (TopologyIndex handles local dev adequately)
- Total: 76 lines added, 0 lines modified

### Benchmark Method: Warm Graph

Same 4-container approach as Approach 1. Graph built in-process, then traversed.

### Results: Warm Graph

| Metric (SQLite) | v1 (ms) | v2 (ms) | Change |
|--------|:---:|:---:|:---:|
| Build (100 nodes, 1K edges) | 1,240 | 1,304 | ~same |
| `-->` (100 results) | 4.0 | 3.9 | ~same |
| `-->(?:PersonNode)` (50) | 2.6 | 2.0 | ~same |

| Metric (MongoDB) | v1 (ms) | v2 (ms) | Change |
|--------|:---:|:---:|:---:|
| Build (100 nodes, 1K edges) | 5,924 | 5,332 | ~same |
| `-->` (600 results) | 13.5 | 15.1 | ~same |

### Analysis: Why Warm Graph Shows No Improvement

The `jac run` benchmark builds the graph and traverses it **in the same process**.
After `root ++> PersonNode(...)`, the node is in L1 (`__mem__` dict). When the walker
does `[-->]`, every `populate()` hits L1 -- **zero L3 fetches**. `batch_get` is a
no-op (all IDs found in L1).

The N+1 problem only manifests when:
1. L1 is empty (fresh request, different worker, cold start)
2. Edges are stubs (loaded from L3 with only UUID, not yet populated)
3. Each `populate()` triggers an individual L3 fetch

### Benchmark Method: Cold Start

To simulate production, we clear L1 and measure individual `find_one()` calls vs
`find({$in: [...]})` batch queries against MongoDB directly. This isolates the
database layer -- the exact cost that `batch_get` eliminates.

### Results: Cold Start (MongoDB)

Empty L1 cache, all reads from MongoDB. Measures actual database round-trip cost.

#### Small Graph (100 nodes, root with 100 edges)

| Method | DB Queries | Avg Latency | Speedup |
|--------|:---:|:---:|:---:|
| N+1 (`find_one` per anchor) | 201 | 159 ms | baseline |
| `MongoBackend.batch_get()` API | 3 | 30.6 ms | **5.2x** |
| Raw pymongo `$in` | 3 | 8.7 ms | **18x** |

#### Medium Graph (500 nodes, root with 500 edges)

| Method | DB Queries | Avg Latency | Speedup |
|--------|:---:|:---:|:---:|
| N+1 (`find_one` per anchor) | 1,001 | 1,539 ms | baseline |
| `MongoBackend.batch_get()` API | 3 | 462 ms | **3.3x** |
| Raw pymongo `$in` | 3 | 65.7 ms | **23x** |

### Analysis

The cold-start benchmark validates the `batch_get` hypothesis:
- **N+1 → batch reduces queries from 201/1001 to 3** -- the database does one indexed
  `$in` lookup instead of hundreds of individual `find_one` calls
- **`batch_get` API delivers 3-5x improvement** -- limited by deserialization overhead
  in `_load_anchor()` (each anchor must be individually deserialized from the blob)
- **Raw `$in` delivers 18-23x** -- shows the ceiling if deserialization were batched
  or eliminated
- **Zero write overhead** -- build times identical between v1 and v2

The gap between raw `$in` (18-23x) and `batch_get` API (3-5x) is the deserialization
cost. Each anchor blob must be individually parsed by `Serializer.deserialize()`.
Optimizing the deserializer is a separate concern from the query pattern.

---

## 4. Key Findings

### Finding 1: The N+1 problem is invisible in single-process benchmarks

When the graph is built and traversed in the same process, everything is in L1.
The `populate()` calls never reach L3. Any optimization to the L3 query pattern
(batch, JOIN, pipeline) shows zero effect because L3 is never hit.

**Implication:** Benchmarks must simulate production cold-start conditions (empty L1)
to measure storage optimization impact.

### Finding 2: Write overhead dominates for schema-based approaches

Adding queryable columns/fields to the storage schema (Approach 1) multiplies write
cost because:
- Every `put()` must extract metadata from the anchor object
- Larger documents increase serialization/network cost
- Database indexes must be updated on every write
- In MongoDB, 3 partial indexes × N writes = 3N additional index operations

**Implication:** Storage optimizations must avoid write-path changes. Read-path-only
approaches like `batch_get` have zero write overhead.

### Finding 3: The Jac runtime traversal code is the actual bottleneck

The runtime's `edges_to_nodes()` iterates `node.edges` and calls `populate()` on
each stub sequentially. This design assumes in-memory access (L1 hit) and degrades
linearly with L3 latency.

**Implication:** The fix must change the runtime traversal code -- not just the
storage schema or query capabilities.

### Finding 4: SQLite (local dev) doesn't need optimization

Local SQLite operates at sub-millisecond latency per query. Even the N+1 pattern
with 50 edges completes in <5ms total. The TopologyIndex provides adequate
optimization for type-filtered queries in this tier.

**Implication:** Storage optimizations should target jac-scale (MongoDB) and
enterprise (PostgreSQL) where network latency makes N+1 expensive.

### Finding 5: `batch_get` is the minimal correct approach

`batch_get` changes only the read path, requires no schema changes, adds zero
write overhead, and is transparent to developers. It reduces 2N+1 sequential
database round-trips to 3 batch queries (1 root + 1 batch edges + 1 batch targets).

The theoretical speedup is:
- For N edges with T ms network latency: `(2N+1) × T` → `3 × T`
- N=100, T=2ms: 402ms → 6ms = **67x**
- N=20, T=5ms: 205ms → 15ms = **14x**

---

## 5. Benchmark Walker Entry Pattern Discovery

During benchmarking, we discovered that `` `root `` (backtick root) does NOT trigger
walker entry abilities in jaclang 0.12.2. The correct pattern is `Root` (capital R):

```jac
# WORKS
walker MyWalker {
    can go with Root entry { ... }
}

# DOES NOT FIRE
walker MyWalker {
    can go with `root entry { ... }
}
```

This is relevant for any future benchmarking or walker development.

---

## 6. Benchmark Infrastructure

All benchmarks use Docker containers built from source (no pre-built packages).
v1 containers are built from `upstream/main`, v2 from the PR branch. Same benchmark
`.jac` script runs in both.

### Files

| File | Purpose |
|------|---------|
| `benchmark.jac` | End-to-end Jac walker benchmark (build + traverse) |
| `benchmark_cold.py` | Cold-start MongoDB benchmark (empty L1, direct pymongo) |
| `bench_jac.Dockerfile` | Container for `jac run benchmark.jac` |
| `bench_cold.Dockerfile` | Container for cold-start Python benchmark |
| `bench_jac_scale_v2.Dockerfile` | Container with jac-scale + MongoDB |

### Running

```bash
# SQLite A/B
docker build -f bench_jac.Dockerfile -t bench-v1 .  # from main
docker build -f bench_jac.Dockerfile -t bench-v2 .  # from PR branch
docker run --rm bench-v1
docker run --rm bench-v2

# MongoDB A/B
docker run -d --name mongo --rm --tmpfs /data/db -p 27099:27017 mongo:7
docker run --rm --link mongo -e MONGODB_URI=mongodb://mongo:27017 bench-v1-mongo
docker run --rm --link mongo -e MONGODB_URI=mongodb://mongo:27017 bench-v2-mongo
```

---

## 7. Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-21 | Reject structured metadata columns (PR #5270) | 9x write regression on MongoDB, no runtime read benefit |
| 2026-03-22 | Remove SQLite changes | No value over TopologyIndex for local dev |
| 2026-03-22 | Pursue batch_get (read-path only) | Zero write overhead, targets the actual bottleneck |
| 2026-03-22 | Cold-start benchmark required | Warm-graph benchmarks don't expose the N+1 problem |
| 2026-03-22 | batch_get validated at 3-5x (API) / 18-23x (raw) | Cold-start MongoDB confirms order-of-magnitude improvement |
| 2026-03-22 | Deserialization is the next bottleneck | Gap between raw $in and batch_get API = deserialization cost |

---

## 8. Deserialization Bottleneck Analysis

The gap between raw `$in` (18-23x) and `batch_get` API (3-5x) is the cost of
`Serializer.deserialize()` called per anchor.

### What Deserialization Does (per anchor)

1. Parse `__type__` field, dispatch to `_deserialize_anchor()`
2. Construct `UUID()` for `id` and `root` fields
3. Reconstruct `Permission` + `Access` + `AccessLevel` objects
4. Reconstruct full archetype with all dataclass fields via `_deserialize_archetype()`
5. **NodeAnchor**: loop through `edges` array, create `EdgeAnchor` stub per edge ID
6. **EdgeAnchor**: create `NodeAnchor` stubs for `source` and `target`

For a NodeAnchor with 20 edges, deserialization creates 1 NodeAnchor + 1 Permission +
1 Access + 1 archetype + 20 EdgeAnchor stubs = **24 Python objects**.

For 500 anchors: 12,000+ Python objects constructed sequentially.

### Why It Can't Be Easily Batched

Each anchor's deserialization is independent -- there's no shared state between
anchors that could be amortized. The `Serializer` uses recursive dispatch
(`_deserialize_value` → `deserialize` → type-specific handler) which prevents
vectorization.

### Possible Future Optimizations

1. **Lazy archetype deserialization**: Don't deserialize the archetype until first
   attribute access. Store raw dict, deserialize on demand. Saves cost for anchors
   that are only used for graph structure (edge traversal) not field access.

2. **Compact binary format**: Replace JSON dict serialization with `msgpack` or
   `pickle` for faster deserialization. `pickle.loads` is 5-10x faster than
   recursive dict reconstruction.

3. **Stub-only batch mode**: When `batch_get` is called for prefetch, return
   partially-constructed anchors (id + edges + source/target stubs only, no
   archetype) since the prefetch only needs graph topology, not field values.

These are separate optimizations from `batch_get` and should be evaluated
independently.

---

## 9. Relationship to TopologyIndex

The TopologyIndex (PR #5205) and `batch_get` solve different parts of the same problem:

| Aspect | TopologyIndex | batch_get |
|--------|:---:|:---:|
| **What it eliminates** | Unnecessary UUIDs (type filter before fetch) | Unnecessary round-trips (batch fetch) |
| **When it helps** | Type-filtered queries (`-->(?:Type)`) | All traversals (typed or untyped) |
| **Where it lives** | In-memory binary blob on root node | Database query pattern |
| **Write cost** | Re-encoded on every graph mutation | Zero |
| **Scale limit** | Application memory (~8 bytes/edge) | Database `$in` query size |

**They are complementary:**
1. TopologyIndex resolves `-->(?:PersonNode)` to a UUID set (e.g., 50 out of 500)
2. `batch_get` fetches those 50 UUIDs in 1 query instead of 50 queries

Without TopologyIndex: `batch_get` fetches all 500 edges + 500 targets = 2 queries.
With TopologyIndex: `batch_get` fetches only 50 matching targets = 1 query.
Both together: optimal -- filter first, then batch fetch the filtered set.

---

## Appendix A: Code Trace -- What Happens When a Walker Executes `[-->]`

1. Compiler generates `refs(ObjectSpatialPath)` call
2. `refs()` calls `edges_to_nodes(origin, destination)` per hop
3. `edges_to_nodes()` iterates `nanch.edges` -- list of stub EdgeAnchors
4. Accessing `anchor.source` triggers `__getattr__` → `populate()` → `mem.get(id)`
5. `mem.get(id)`: L1 hit → return; L1 miss → L3 query → promote to L1
6. Accessing `target.archetype` triggers another `populate()` → another `mem.get(id)`
7. **Per edge: 2 sequential database fetches (source + target)**
8. **Total for N edges: 2N+1 fetches**

With `batch_get`:
1. `_prefetch_edges()` collects all edge stub IDs
2. `batch_get(edge_ids)`: single `find({_id: {$in: [...]}})` → warm L1
3. Collects all target node IDs from loaded edges
4. `batch_get(target_ids)`: single `find({_id: {$in: [...]}})` → warm L1
5. Original filter loop runs -- all `populate()` calls hit L1
6. **Total: 3 database fetches regardless of N**
