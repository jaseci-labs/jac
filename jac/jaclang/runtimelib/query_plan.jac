"""QueryPlan IR — the contract between the runtime planner and storage backends.

A QueryPlan describes a graph query in storage-neutral terms so the planner can
either hand it to a backend's native `execute_plan` (e.g. MongoDB compound index
+ `_id $in` pushdown, Postgres jsonb GIN) or fall back to the universal floor
(root topology_index → set narrowing → `batch_get`).

The IR captures only the shapes we can actually optimize today; complex
predicate lambdas stay on the slow path. Anything not representable as a
declarative dict belongs in the post-filter the runtime applies above.

Capability strings backends declare via `Memory.capabilities()`:

  - `'type_pushdown'`   — backend can filter by archetype type natively
                          (e.g. an `arch_type` index in Mongo/Sqlite).
  - `'field_pushdown'`  — backend can apply declarative field predicates
                          on archetype data without loading rows
                          (e.g. Mongo `data.archetype.*` filter dict,
                          Postgres jsonb path ops).
  - `'id_in'`           — backend can filter by `_id IN (...)`; required
                          when the topology_index narrows to a candidate set
                          and we want the backend to materialize that subset.
  - `'slice'`           — backend can apply `(offset, limit)` natively
                          (otherwise the planner slices the result list).

A backend's `execute_plan(plan)` returns:
  - `Generator[Anchor, ...]`  when it fully handled the plan
  - `None`                    to opt out and let the planner use the floor

The planner trusts the backend's claim — if a plan needs `'field_pushdown'`
and the backend declares it, the result is taken as authoritative. Mixed
strategies (narrow with the index, materialize via backend `id_in`) are
composed by the planner, not by the backend.
"""

import from collections.abc { Callable }
import from uuid { UUID }
import from jaclang.jac0core.archetype { Anchor }

glob __all__ = ['HopSpec', 'QueryPlan'];


"""One hop in a path expression: `[edge_type? -[direction]-> node_type?]`.

`edge_type` / `node_type` are bare archetype class names (no module prefix);
the topology_index resolves them via MRO fan-out so subclass matches "just
work". `direction` mirrors `EdgeDir`: 1=IN, 2=OUT, 3=ANY.
"""
obj HopSpec {
    has edge_type: (str | None) = None,
        node_type: (str | None) = None,
        direction: int = 2;
}


"""Declarative query plan handed to backends or executed by the floor.

Fields are populated by `planner._build_plan_from_path` (the IR builder)
from the runtime's `ObjectSpatialPath`. None of these is required — a plan
with only `chain` and a `root_id` is the common case for `[root -->]`.

Field reference:

  - `root_id`         the root anchor that owns the subgraph. Used both as the
                      adjacency origin for the topology_index and as the
                      access-control scope for backends that partition by root.
  - `chain`           ordered list of HopSpec. Empty chain = "match anchors in
                      this root with no traversal" (e.g. for `query_by_type`-
                      style scans).
  - `field_predicates` archetype-field constraints, keyed by bare field name
                      with MongoDB-style operator values:
                          `{'age': {'$lt': 28}, 'status': 'active'}`
                      Backends prefix field names with whatever path they use
                      (`data.archetype.<f>` in Mongo, jsonb path in PG).
                      Operators understood across backends: `$eq`, `$ne`,
                      `$lt`, `$lte`, `$gt`, `$gte`, `$in`, `$nin`. Anything
                      else is backend-specific.
  - `id_in`           when the planner has already narrowed to a candidate
                      set (typically via the topology_index), this carries
                      that set so the backend can do a single `_id IN (...)`
                      lookup. None means "no candidate narrowing applied".
  - `slc`             optional slice. The planner sets this when the user
                      wrote `[-->][0:50]` and the chain is pushdown-eligible.
                      Backends without `'slice'` capability should ignore it;
                      the planner slices afterwards.
  - `node_type_final` archetype class name to match on the final result set.
                      Distinct from chain hops because it can be checked
                      directly via the `arch_type` index without graph
                      traversal — the cheap path when chain is empty.
  - `post_filter`     opaque callable from the runtime; the planner applies
                      it AFTER any backend execution. Not pushdown-eligible.
"""
obj QueryPlan {
    has root_id: (UUID | None) = None,
        chain: list[HopSpec] = [],
        field_predicates: dict = {},
        id_in: (set[UUID] | None) = None,
        slc: (slice | None) = None,
        node_type_final: (str | None) = None,
        post_filter: (Callable[[Anchor], bool] | None) = None;

    def is_trivial -> bool;
    def needs -> set[str];
    def repr -> str;
}
