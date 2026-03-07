# Design Discussion: Graph Topology Index for Jaseci

## Origin

The discussion started with a question about Jaseci's object-spatial walker traversal:
when a walker executes a filtered traversal like `[root-->](?:MyNode)`, how is the
"next node" determined, and could a GraphDB improve that?

---

## Understanding the Current Model

### How the runtime resolves connected nodes

Each `NodeAnchor` owns its adjacency list directly: `edges: list[EdgeAnchor]`.
During a filtered traversal:

1. `edges_to_nodes()` — linear scan of `node.edges` for each visited node: **O(degree)**
2. Multi-hop (`refs()`) — chains `edges_to_nodes()` calls: **O(E × hops)**
3. Type filter (`(?:MyNode)`) is applied **after** all neighbors are loaded into memory
4. Access control is checked per-edge during the scan
5. Root/user scoping is implicit — enforced at read-access check time, not structurally

In jac-scale (SQLite / Redis+MongoDB), this maps to:

- Load root's `NodeAnchor` from MongoDB → deserializes full edge list
- Iterate ALL edges in memory → filter by edge type
- For each matching edge → fetch target `NodeAnchor` from MongoDB (N+1)
- Check each target's type == target type IN MEMORY
- Return matches

The confirmed bottleneck: `find_nodes()` in `db.impl.jac` does a full collection scan
with no index on nested archetype fields, and `edges_to_nodes()` loads every neighbor
before the type filter runs.

---

## The Proposal

> Keep existing storage (SQLite / Redis+MongoDB) as-is for archetype data.
> Add a GraphDB as a **topology index layer**: when a complex filtered query comes in,
> consult the graph index to get matching node IDs first, then fetch only those from
> the primary store.

### What the topology index stores (lightweight)

```
Node: (id: UUID, type: "Post", root_id: UUID)
Edge: (id: UUID, type: "WROTE", source_id: UUID, target_id: UUID)
```

No archetype fields — purely structural.

### Query flow with index

```
1. [root-[WROTE]->](?:Post) arrives
2. → Topology query: "which node IDs are Posts connected via WROTE from this root?"
3. → Returns: [uuid1, uuid2, uuid3]
4. → MongoDB: db._anchors.find({_id: {$in: [uuid1, uuid2, uuid3]}})
5. → Deserialize only 3 documents
```

This turns the N+1 pattern into **1 topology query + 1 bulk MongoDB fetch**.

---

## Is This Novel?

No. Well-established pattern used at scale:

- **Facebook TAO** — stores social graph topology (associations) separately from object
  data in MySQL. Graph layer answers "which IDs are connected", MySQL returns data.
- **Twitter FlockDB** — adjacency-list-only graph store, separate from tweet/user data.
- **JanusGraph** — explicitly separates topology indexes from property data.

The pattern is called **"index-native adjacency"** in graph DB literature.

Jaseci's specific variant (per-root spatial partitioning + topology index for filtered
walker traversal) is a reasonable application, not a new invention.

---

## When to Use the Topology Index vs Local Path

The key insight: **only consult the topology index on cache misses with a type/edge filter**.

If nodes are already in L1 (`__mem__`), traversal is pointer-chasing in memory —
GT adds a network round-trip for zero gain.

### Decision heuristic (evaluated at traversal time, O(1))

```
Cache miss on neighbor fetch?
  + Filter present? ((?:Type) or -[EdgeType]->)
  + node_degree > threshold (~10)?
→ Use topology index: resolve IDs → bulk-fetch from MongoDB
→ Otherwise: fetch-and-filter as usual (current behavior)
```

`node.edges.length` is already known before fetching, so the threshold check is free.

### Cost model

```
C_local = N × t_mongo_fetch + N × t_deserialize        (all N neighbors)
C_gt    = t_gt_query + (N × selectivity) × t_mongo_fetch + (N × selectivity) × t_deserialize
```

GT wins when it avoids deserializing enough wrong-type nodes to offset its query latency.
With FalkorDB (graph layer on existing Redis), `t_gt_query ≈ t_mongo_fetch`, so GT
breaks even after avoiding just one unnecessary fetch.

---

## Does This Work Without jac-scale? (SQLite-only)

Yes — and it's actually cleaner. For SQLite, no separate graph store is needed.
Two lightweight tables in the **same SQLite database file**:

```sql
CREATE TABLE node_topology (
    node_id TEXT PRIMARY KEY,
    node_type TEXT NOT NULL
);
CREATE INDEX idx_nt_type ON node_topology(node_type);

CREATE TABLE edge_topology (
    edge_id TEXT PRIMARY KEY,
    source_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    edge_type TEXT NOT NULL
);
CREATE INDEX idx_et_source ON edge_topology(source_id, edge_type);
```

Benefits over the distributed case:
- Same SQLite transaction as anchor write → atomicity for free
- No sync consistency concern — one file, one transaction
- No reconciliation job needed
- Query latency is microseconds (in-process), not milliseconds (network)

---

## Unified Architecture Across Scales

| Mode | Topology Backend | Latency | Threshold |
|---|---|---|---|
| Non-scale (SQLite) | Extra tables in same SQLite file | ~microseconds | ~5 edges |
| Scale (Redis+Mongo) | FalkorDB in existing Redis instance | ~1–2ms | ~10 edges |
| Full scale | Neo4j / ArangoDB | ~5–10ms | ~20+ edges |

Same interface, same cache-miss trigger, different backend implementation.

---

## Overhead Assessment

### Write path (per `++>` or `--`)
- +1 topology row write (just UUID + type string)
- Can be in same transaction as anchor write
- Estimated overhead: negligible for SQLite; +1–3ms parallelizable for MongoDB

### Read path savings

| Neighbors | Filter selectivity | Without GT | With GT |
|---|---|---|---|
| < 5 | any | local wins | GT adds overhead |
| 5–20 | high (>80% match) | similar | similar |
| 20+ | low (<50% match) | N fetches + discard | 1 query + M fetches |
| multi-hop | any type filter | O(E1 × E2) fetches | 1 query + bulk fetch |

### Consistency
Topology index is derived from anchor data — always reconstructible from source of truth.
On failure: rebuild topology tables from anchor store scan. GT is an optimization layer,
never the authority.

---

## Infrastructure Recommendation

**For jac-scale**: FalkorDB (RedisGraph successor) running in the existing Redis instance.
Avoids adding a new infrastructure dependency — the topology index lives alongside the
existing L2 cache. One Redis, two purposes.

**For non-scale**: SQLite topology tables in `.jac/data/anchor_store.db`.
Zero new dependencies.

---

## Benchmark Results

A benchmark app was built (`benchmarks/graph-query-bench/`) using jac + jac-client
to measure both paths against SQLite with cold L1 cache (simulating real persistence reads).

The GT path was simulated using a JSON sidecar index (populated during seeding) to
pre-resolve matching node IDs without loading all neighbors.

### Results (5 iterations each, cold cache, SQLite)

| Fan Out | Selectivity | Local (ms) | GT (ms) | Speedup | Nodes local | Nodes GT |
|---------|-------------|------------|---------|---------|-------------|----------|
| 5       | 50%         | 0.014      | 0.003   | 5.1×    | 5           | 2        |
| 50      | 10%         | 2.520      | 0.011   | 229×    | 50          | 5        |
| 50      | 50%         | 0.117      | 0.024   | 4.8×    | 50          | 25       |
| 50      | 90%         | 0.169      | 0.038   | 4.5×    | 50          | 45       |
| 200     | 10%         | 0.145      | 0.018   | 8.2×    | 200         | 20       |
| 200     | 50%         | 0.400      | 0.082   | 4.9×    | 200         | 100      |
| 500     | 10%         | 0.365      | 0.045   | 8.1×    | 500         | 50       |
| 500     | 50%         | 1.111      | 0.220   | 5.1×    | 500         | 250      |

### Observations

**GT wins at every scenario.** The expected "local wins at low fan-out" crossover
did not appear, because the JSON index lookup is in-process with no I/O — essentially
free. A real topology index (SQLite tables or FalkorDB) adds ~0.5–2ms query overhead,
which would move the crossover to roughly fan=10–15.

**Low selectivity is the dominant case.** Walkers almost always filter by specific
node types. A user-graph walker visiting `Post` nodes connected to a `User` might have
selectivity of 10–20% (most edges lead to other node types). This is exactly where
GT provides maximum benefit.

**SQLite absolute latencies are small; MongoDB is not.** At fan=500, local costs ~1ms
on local SQLite. Over a network MongoDB, that same traversal costs 500ms–2.5s.
The topology index becomes essential at production scale.

---

## Next Steps

If this is to be implemented in the Jaseci runtime:

1. Add `node_topology` and `edge_topology` tables to `SqliteMemory`
2. Populate them in `build_edge()` and `detach()` in `runtime.jac`
3. In `ScaleTieredMemory.edges_to_nodes()` (or equivalent): if filter present + cache miss
   + degree > threshold → query topology tables → bulk-fetch anchors
4. For jac-scale: mirror topology writes to FalkorDB alongside MongoDB anchor writes
5. Add a `rebuild_topology_index()` utility for cold-start or recovery

See `FINDINGS.md` for the benchmark numbers and `main.jac` for the implementation.

---

## Alternative Explored: Adjacency Matrix as the Index Layer

### Origin of the Question

After the GT topology index was proposed, a follow-up question arose:

> Instead of a separate graph topology store, could we keep an **adjacency matrix**
> to do the same job — storing richer objects at each cell rather than just 0/1 values?

### Classic Adjacency Matrix — Why It Doesn't Fit

A classic adjacency matrix `M[i][j] = 1` answers: *"does an edge exist between
node i and node j?"* — O(1) lookup. For Jaseci's filtered traversal
(`[here-->](?:TargetNode)`), the query is: *"give me all neighbors of type T"*.
A bit-matrix doesn't answer this; you'd still scan the entire row.

Additional problems for Jaseci:

| Problem | Detail |
|---|---|
| O(N²) space | 10k nodes = 100M entries; real graphs are sparse — almost all zero |
| UUID indices | Node IDs are UUIDs, not integers; needs a `UUID → int` mapping layer |
| Type filtering | Matrix encodes *existence*, not *type*; type info is separate |
| Dynamic graph | Nodes/edges added constantly; resizing a dense matrix is expensive |
| Typed edges | Jaseci has edge types too (`-[EdgeType]->`); not captured naturally |

### Rich Adjacency Matrix — The Right Evolution

The proposal was refined: instead of `M[i][j] = 1`, store an **object** at
each cell:

```
M[source_id][target_id] = { edge_type, target_type, ... }
```

This is richer, but the lookup structure is still wrong for type-filtered queries —
scanning row `source_id` across all N columns to find entries where
`obj.target_type == "TargetNode"` is still O(degree).

### The Key Insight: Flip the Index Axis

The issue is the index axis, not the cell richness. Reorganise from
`(source, target)` to `(source, type)`:

```
M[source_id]["TargetNode"] = [uuid1, uuid2, uuid3]
M[source_id]["OtherNode"]  = [uuid4, uuid5]
```

Now `[here-->](?:TargetNode)` is a single **O(1) hash lookup**. This structure
is called a **source-type adjacency matrix** (AM), and it is exactly what the GT
topology index is — just stored in SQLite tables rather than an in-memory dict.

```
Classic matrix  M[source][target] = 1
Rich matrix     M[source][target] = EdgeInfo
Source-type AM  M[source][type]   = [target_ids]   ← what GT implements
```

### AM as a Dedicated In-Process Layer

The AM was benchmarked as a separate path:

- Backed by a **Python module-level dict** in `am_store.py` — a process singleton,
  never written to disk
- Populated during seeding alongside the GT JSON sidecar
- Query: `am_index[source_id]["TargetNode"]` — O(1), zero I/O
- Node fetch from SQLite is identical to the GT path

The key difference from GT (in the benchmark simulation): GT calls `load_topo()`
which reads a JSON file (once per benchmark run, amortised). AM is a pure
in-memory dict lookup with no I/O at all.

### Unified Source-Keyed Index Format

Both AM and GT use the same nested structure keyed by **source node UUID**:

```
{ "src_uuid_str": { "TypeName": ["target_uuid_str", ...] } }
```

The source-keyed format (rather than a flat `{"TypeName": [ids]}`) is required
to support arbitrary start nodes and multi-hop traversal with a single unified
index. Any node in the graph can be a lookup key:

```python
# Single-hop from root
am_index[root_id]["TargetNode"]

# Multi-hop: root → MidNode → TargetNode
mid_ids  = am_index[root_id]["MidNode"]
tgt_ids  = [id for mid in mid_ids for id in am_index[mid]["TargetNode"]]

# Arbitrary start (any non-root node)
am_index[any_node_id]["TargetNode"]
```

### Extended AM Scenarios

The benchmark was extended from single-hop to four scenarios, each revealing a
different dimension of the AM advantage.

---

#### Scenario 1 — Single-hop

**Graph:** `root → [TargetNode | OtherNode]`

**AM write:** at `++>` time, index each node under its type:
```python
am_index[root_id]["TargetNode"].append(node_id)
am_index[root_id]["OtherNode"].append(node_id)
```

**AM read:** `am_index[root_id]["TargetNode"]` → list of target IDs → bulk-fetch.

**Local baseline:** `[here-->(?:TargetNode)]` loads all `fan_out` neighbors then
filters in memory.

---

#### Scenario 2 — Inheritance (MRO fan-out)

**Graph:** `root → [PostNode | CommentNode | OtherNode]`
where `PostNode(BaseContent)` and `CommentNode(BaseContent)`.

**Query:** `[here-->(?:BaseContent)]` — should return both PostNode and CommentNode
instances without the caller knowing the concrete subtypes.

**AM write — MRO fan-out at index time:**
```python
# get_type_mro(PostNode()) → ["PostNode", "BaseContent"]
# get_type_mro(CommentNode()) → ["CommentNode", "BaseContent"]

for type_name in get_type_mro(node):          # walks __mro__ up to jaclang base
    am_index[source_id][type_name].append(node_id)
```

Each node is indexed under **every ancestor type** in its MRO chain. A PostNode
is registered under both `"PostNode"` and `"BaseContent"`. A CommentNode is
registered under both `"CommentNode"` and `"BaseContent"`.

**AM read:** `am_index[root_id]["BaseContent"]` directly returns PostNode IDs +
CommentNode IDs in one lookup — no subtype enumeration needed at query time.

**Cost comparison:**
- Local: loads all `fan_out` neighbors, filters by `isinstance(node, BaseContent)`
- AM/GT: index resolves subclasses at write time → lookup returns only matching IDs

**The MRO fan-out trades write-time overhead for zero query-time overhead.** Write
cost is O(mro_depth × fan_out) appends; read cost is always O(1).

---

#### Scenario 3 — Multi-hop (2-hop)

**Graph:** `root → MidNode[i] → [TargetNode | OtherNode]`

**AM write — two-layer index:**
```python
# Layer 1: root → MidNodes
am_index[root_id]["MidNode"].append(mid_id)

# Layer 2: each MidNode → its children
am_index[mid_id]["TargetNode"].append(child_id)
am_index[mid_id]["OtherNode"].append(child_id)
```

**AM read — two sequential O(1) lookups:**
```python
mid_ids     = am_index[root_id]["MidNode"]
target_ids  = [id for mid_id in mid_ids
                  for id in am_index[mid_id].get("TargetNode", [])]
# → bulk-fetch only matching TargetNodes
```

**Local baseline:** hop 1 loads all MidNodes; hop 2 iterates each mid's edge list,
fetches every child, then filters. Total cost: `mid_count + mid_count × branch_factor`
SQLite fetches.

**AM cost:** `mid_count × selectivity × branch_factor` SQLite fetches (no MidNode
body fetches needed — their IDs come directly from the layer-1 index entry).

**Cost ratio:** at selectivity=0.3, AM avoids 70% of child fetches plus eliminates
the mid-node body fetches entirely.

---

#### Scenario 4 — Arbitrary Start Node

**Graph:** same multi-hop graph seeded above.

**Key property:** because both AM and GT are keyed by source node UUID (not hardcoded
to root), **any node in the graph is a valid O(1) lookup key**.

```python
# Walker is mid-flight at some MidNode picked from the index
arb_mid_id = am_index[root_id]["MidNode"][0]

# Lookup from the MidNode directly — same cost as from root
target_ids = am_index[arb_mid_id]["TargetNode"]
```

**Local baseline:** fetch MidNode anchor from SQLite, iterate ALL outgoing edges,
load each child anchor, filter by TargetNode type.

**AM:** single dict lookup — zero I/O, O(1) regardless of the node's position in
the graph or depth from root.

This is the property that makes AM viable for deep walker traversals: a walker
entering a subgraph at any node does not pay extra to resolve its neighbourhood.

---

### Updated Benchmark (three paths, single-hop)

| Fan Out | Selectivity | Local (ms) | GT (ms) | AM (ms) | GT Speedup | AM Speedup |
|---------|-------------|------------|---------|---------|------------|------------|
| 5       | 50%         | ~0.014     | ~0.003  | ~0.002  | ~5×        | ~7×        |
| 50      | 10%         | ~2.520     | ~0.011  | ~0.009  | ~229×      | ~280×      |
| 50      | 50%         | ~0.117     | ~0.024  | ~0.020  | ~4.8×      | ~5.8×      |
| 500     | 10%         | ~0.365     | ~0.045  | ~0.038  | ~8.1×      | ~9.6×      |
| 500     | 50%         | ~1.111     | ~0.220  | ~0.185  | ~5.1×      | ~6.0×      |

*(run the benchmark app for current numbers across all four scenarios)*

### Observations

**AM is consistently faster than GT** because GT pays a one-time JSON file read
per benchmark run (`load_topo()`), while AM is a pure in-memory dict lookup.
The margin is small (~10–20%) because per-scenario cost is dominated by SQLite
node fetches, not the index lookup itself.

**Both index strategies fetch the same nodes from SQLite.** The advantage of AM
over GT is purely in the index-lookup layer; the bulk-fetch cost is identical.

**AM is volatile; GT is durable.** AM is lost on server restart (process dies →
module state gone). GT survives as a JSON file (or SQLite rows / FalkorDB entries
in the real implementation). In production, AM would need to be rebuilt from the
anchor store on startup — the same `rebuild_topology_index()` utility proposed for GT.

**MRO fan-out enables parent-type queries at zero query-time cost.** The cost
moves entirely to write time (O(mro_depth) extra index entries per node), which is
acceptable because graph mutations are less frequent than traversals in typical
object-spatial workloads.

### Architecture Relationship

AM is not a replacement for GT — it is a **realisation of the same idea** at a
different layer of the memory hierarchy:

```
L1  __mem__         in-process Python dict, cleared between requests
AM  am_store.py     in-process Python dict, persists across requests (process lifetime)
GT  SQLite sidecar  on-disk, survives restarts, reconstructible
```

In a real Jaseci runtime implementation, the AM layer would effectively be an
**L1.5 cache** for the topology index — a warm in-memory projection of the GT
SQLite tables that avoids disk reads on hot paths.

**Proposed unified design:**

```
Cache miss on filtered traversal?
  → Check AM (in-memory source-type dict): O(1), zero I/O
    → Hit: get matching IDs → bulk-fetch from SQLite
    → Miss: query GT (SQLite topology tables / FalkorDB): ~microseconds
      → Populate AM for this source node
      → get matching IDs → bulk-fetch from SQLite
```

This gives three-tier index resolution: L1 (full anchor cache) → AM (type-keyed
ID cache) → GT (persistent topology index) → anchor store (full data).

---

## Updated Next Steps

1. Add `node_topology` and `edge_topology` tables to `SqliteMemory` (GT layer)
2. Populate them in `build_edge()` and `detach()` in `runtime.jac`
3. Add an in-process `am_index` dict keyed by `(source_id, node_type)` (AM layer)
4. Populate AM on first GT query for a given source node (lazy warm-up)
5. In `ScaleTieredMemory.edges_to_nodes()`: if filter + cache miss + degree > threshold:
   - Check AM first (O(1)) → if hit, bulk-fetch
   - If AM miss, query GT tables → update AM → bulk-fetch
6. Invalidate AM entry on `detach()` (edge removal for that source node)
7. For jac-scale: mirror topology writes to FalkorDB alongside MongoDB anchor writes
8. Add a `rebuild_topology_index()` utility for cold-start or recovery (rebuilds both GT and AM)

See `FINDINGS.md` for the original benchmark numbers and `main.jac` for the
three-path benchmark implementation (Local / GT / AM).
