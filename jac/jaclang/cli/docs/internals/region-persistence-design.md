# Region-Granular Persistence: Design Pass

Status: design only. Issue #7870 item 6c licenses exactly this document;
no code lands with it. The feature is the far end of connect-as-seal
(#7857 R4, landed #7858): a sealed region is already a frozen, immortal,
bulk-owned subgraph -- this design says what it means to promote one
into the anchor store as a **storage segment** and load it back.

## 1. What exists today (the facts this design builds on)

- **Connect-as-seal** (`ownership_check_pass.impl/region.impl.jac`,
  `_seal_connect_handle`): a directed connect from a managed anchor into
  a region-local node, under an open on an owned named handle, consumes
  the handle and promotes the subgraph into the managed world. Pages
  stay live, teardown never runs. The seal is the membrane: after it,
  the subgraph traverses from the anchor like any managed graph.
- **The anchor store** (`data/store.jac`,
  `data/impl/store.impl.jac`): the Postgres `PgStore` with one
  `anchors` table
  `anchors(id, kind, arch_type, arch_module, fingerprint, root_id,
  src, dst, undirected, props, format_version, version, updated_at,
  seq)` holding nodes and edges alike -- an edge is a row with
  `src`/`dst` set -- plus `graph_types` (the type-ancestry index) and
  `kv_state`. Writes go through versioned upserts (the `version`
  column; a lost race raises `WriteConflict`).
- **Persistence by reachability** (`docs/reference/persistence.md`):
  what `root` reaches persists. A sealed subgraph becomes reachable
  through its seal anchor, so today it would persist as ordinary
  per-anchor rows -- one row and one UUID per node, all arena locality
  lost at the store boundary.
- **The arena** (`na_ir_gen_pass.impl/region.impl.jac`): a sealed
  region's memory is a chunk list of bump-allocated pages; objects
  reference each other by raw pointer. This is the locality the store
  currently throws away.

## 2. Goal and non-goals

Goal: a sealed region persists and reloads as **one unit** -- one write
for the build-and-seal idiom, one read to hydrate, arena-shaped
locality preserved on disk, per-anchor row cost avoided for the
region's interior.

Non-goals (this pass): partial/per-page hydration, mutable segments,
cross-segment interior edges beyond the seal edge, distributed segment
coherence (jac-scale L1 invalidation extends later; the L3 contract
addition below is designed to make that possible, not to deliver it).

## 3. Representation

A **segment** is the serialized image of one sealed region.

- **Store shape (hybrid).** One `segments` row holds the opaque image;
  the graph index still gets exploded `graph_edges` rows for every
  intra-segment edge. Rationale: the graph index is the query contract
  (hops and filters must see interior topology without hydrating the
  blob), while node payloads -- the bulk of the bytes -- stay packed in
  the image. Rejected: fully exploded per-anchor rows (no locality, no
  bulk IO win, the status quo); fully opaque blob including topology
  (every hop query would hydrate).
- **Proposed schema:**
  `segments(id TEXT PK, seal_anchor TEXT, format_version INT,
  manifest TEXT, image BLOB, updated_at)` where `manifest` is JSON:
  the archetype fingerprint set of the interior (the serializer's
  existing per-archetype fingerprints), the node count, and the export
  table (below). `anchors` gains a nullable `segment_id` column: an
  interior node has a row only if exported, and that row carries its
  segment membership.
- **Interior references are segment-relative.** Inside the image,
  node-to-node references are ordinal indices in region allocation
  order, not UUIDs -- the on-disk mirror of "extents are scoped,
  counted, or reified, never named". Only **exported** nodes get UUIDs:
  the seal target always; any interior node that acquires a managed
  in-edge later (segment explosion, section 4). The export table in the
  manifest maps ordinal to UUID for exported nodes.
- **Fingerprints and drift.** The manifest pins the fingerprints the
  image was written under. Hydration applies the serializer's existing
  drift rules per archetype; an incompatible drift explodes the segment
  into ordinary anchors under the migration path (section 4) rather
  than failing the load.

## 4. Lifecycle

- **Promote (persist).** When commit finds a seal anchor whose sealed
  subgraph is newly root-reachable, the runtime serializes the region
  image in allocation order and emits one new changeset op,
  `SEGMENT_CREATE` (image + manifest + seal edge), with `cas_version`
  on the seal anchor. The interior emits no `NODE_CREATE` ops; the
  graph index rows are written in the same transaction
  (`_graph_index_write` already batches).
- **Hydrate (load).** The first hop that crosses the seal edge (or any
  query resolving an exported interior UUID) loads the whole segment:
  one read, one arena, ordinals rebound to fresh in-memory pointers in
  a single pass. On the native backend the natural target is a region
  whose handle the runtime owns (the loaded subgraph is frozen: `imm
  Region` semantics, E1309 on allocation into it); on the Python
  backend it is an ordinary object graph tagged with its segment id.
  Hydration is the exact inverse of promotion, which is what keeps the
  erasure oracle writable.
- **Mutation = explosion.** Segments are frozen at seal, matching the
  in-memory contract (a sealed region admits no further allocation or
  connects, E1307). A field write or connect targeting an interior node
  first **explodes** the segment: interior nodes become ordinary
  anchors (`NODE_CREATE` each, UUIDs minted from the export table where
  present), the segment row is tombstoned (`SEGMENT_EXPLODE` op), and
  the mutation proceeds as a normal changeset. Rejected: in-place image
  patching (write amplification, CAS complexity, and it would make the
  frozen contract a lie).
- **Death.** By the seal contract a segment has exactly one owner: its
  seal anchor. `NODE_DELETE` of the seal anchor cascades to
  `SEGMENT_DELETE` (image row + its graph-index rows), preserving
  persistence-by-reachability with no new GC machinery.

## 5. Surface

No new syntax. Promotion is a property of commit meeting a sealed
subgraph, exactly as persistence today is a property of reachability.
The only observable additions are operational: a segment-count metric
on commit, and a `jac db` introspection view for `segments`.

## 6. Backend portability

`PersistentMemory` gains `get_segment(id)`, `put_segment(row)`,
`delete_segment(id)` with the same must-own-graph-index stance as the
existing contract. Mapping: the Postgres store as in section 3 -- a
`segments` table with `manifest` as `jsonb` and `image` as `bytea`.
(This design predates the Postgres clean break, which retired the
other backends this section once mapped.) `TieredMemory` treats a hydrated
segment as an L1 population event keyed by every exported UUID.

## 7. Invariants and acceptance oracle (for the future code pass)

- **Erasure**: the Python backend implements promote/hydrate/explode
  over `JacRegion` with identical observable behavior; annotations
  stripped, same rows written.
- **Mode invariance**: build-seal-commit-reload-traverse produces
  byte-identical output under `--memory nogc/rc/cycles`.
- **Round trip**: promote then hydrate reproduces the traversal digest
  of the never-persisted graph; the existing ownbench digest machinery
  (`test_ownbench_differential.jac` pattern) extends to a
  `reg_persist` kernel.
- **Explosion equivalence**: mutate-after-reload produces the same
  final store state as building the graph unsealed from the start.

## 8. Open questions (blocking the code pass, in order)

1. Ordinal rebinding cost vs lazy per-node fixup on hydrate: measure a
   large-segment load before choosing eager one-pass rebind.
2. Cross-segment edges other than the seal edge: forbidden here; if a
   real workload needs sibling-segment links, the export table grows
   and hydration gains a dependency order. Decide on demand.
3. Concurrent walk-during-explosion: the CAS on the seal anchor covers
   promote and explode, but a reader holding hydrated pointers across
   an explosion needs the same epoch story as ordinary anchor updates;
   pin down with the jac-scale L1 invalidation work.
4. Image encoding: the serializer's JSON row format is the v1 image
   encoding for portability; a packed binary layout that mirrors arena
   pages byte-for-byte is the v2 candidate once the fat-descriptor
   string migration (#7870 item 1) settles field representations.
