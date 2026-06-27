"""Query planner — picks the execution strategy for a QueryPlan.

The planner is the only place that knows about all three layers:

  1. Backend native pushdown (`Memory.execute_plan`, declared via
     `Memory.capabilities()`). Fastest when the backend can handle the plan
     because it bypasses the topology_index entirely.
  2. Root topology_index (`TopologyIndex.resolve_chain[_ordered]`). The
     universal in-process narrowing path. Always available when the index is
     enabled and the relevant root carries one.
  3. `batch_get` (every backend has this). The bulk-load primitive used after
     narrowing to materialize anchors → archetypes.

Strategy selection:

  * `pushdown`  — `plan.needs() <= backend.capabilities()`. Hand the whole
                  plan to the backend; iterate its generator.
  * `mixed`     — topology_index resolves the chain to a candidate UUID set,
                  the planner attaches that set as `plan.id_in`, and the
                  reduced plan (now needing `id_in` + maybe `field_pushdown`)
                  goes to the backend if it covers those needs. Otherwise the
                  planner falls through to `floor`.
  * `floor`     — topology_index → `batch_get`. Pure in-process. Always
                  works as long as the index is populated.

The planner is also the one place that observes `JAC_QUERY_TRACE` to log
which strategy fired for which plan — invaluable when debugging unexpected
fallbacks or perf cliffs in CI.
"""

import logging;
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, Archetype, NodeAnchor }
import from jaclang.runtimelib.query_plan { QueryPlan }

glob logger = logging.getLogger(__name__),
     __all__ = ['execute_plan', 'execute_path'];


"""Inspect a Jac-emitted filter lambda for archetype-type identity.

Returns the archetype class name if the lambda is a pure `isinstance(i, T)`
check (or an Archetype instance acting as an identity filter). Returns None
when the filter is None or non-trivial.

Memoized by `filt.__code__`. Jac emits filter lambdas inline
at the path-construction call site, so two walker spawns produce two
distinct function objects that share the same code — keying on identity
would never hit; keying on the code does."""
def _filter_type_name(filt: any) -> (str | None);


"""Detect whether a filter lambda contains predicate ops beyond type checks.

Pure `isinstance(i, T)` checks compile to LOAD_GLOBAL + CALL_FUNCTION +
RETURN; predicates introduce LOAD_ATTR / COMPARE_OP / CONTAINS_OP / IS_OP.
Conservative on inspection failure — assume predicates present so we never
silently skip filtering.

Memoized by `filt.__code__`; see `_filter_type_name` for the why."""
def _filter_has_predicates(filt: any) -> bool;


"""Top-level entry point: execute a QueryPlan against a memory.

Returns an iterable of NodeAnchor results. Applies `plan.post_filter` if set.
Trivial plans (no chain, no filters, no narrowing) return empty — callers
should use `Memory.query()` directly for unfiltered scans.

The signature deliberately accepts `any` for `mem` so the planner can be
called from the bootstrap-compiled runtime layer without a circular import on
the Memory type.
"""
def execute_plan(mem: any, plan: QueryPlan) -> list[any];


"""High-level entry point: execute an `ObjectSpatialPath` against a memory.

This is what the runtime's `refs()` calls. Builds the QueryPlan from the
path's destinations, walks the strategy ladder (pushdown / mixed / floor),
applies the final node filter post-narrowing, and returns the result as
NodeAnchors in canonical edge-walk order (single-hop) or arbitrary order
(multi-hop set narrowing).

Always returns a list. The per-hop resolver locally falls back to anchor
walk for hops the index can't cover (predicate filters, foreign roots,
no index), so there is no whole-query bail."""
def execute_path(mem: any, path: any, slc: (slice | None) = None) -> list[any];
