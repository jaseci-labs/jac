"""Shared edge-traversal query helpers.

Single home for the filter-introspection, materialization, and root-anchor
plumbing used by both `planner.execute_plan` (still the entry point for
backend `Memory.execute_plan` callers) and `resolver.resolve_path_anchors`
(the per-hop fold called from `refs()`). Kept here so a future fix to
filter opcode detection or batch_get materialization can't silently miss
one of the duplicates."""

import os;
import logging;
import inspect;
import dis;
import from uuid { UUID }
import from collections.abc { Callable }

import from jaclang.jac0core.archetype {
    Anchor,
    Archetype,
    NodeAnchor,
    ObjectSpatialPath
}
import from jaclang.runtimelib.memory { Memory }

glob logger = logging.getLogger(__name__),
     __all__ = [
         '_trace_enabled',
         '_filter_type_name',
         '_filter_has_predicates',
         '_materialize_ids',
         '_path_root_anchor'
     ];


"""Truthy `JAC_QUERY_TRACE` toggles per-call query trace logging."""
def _trace_enabled -> bool;


"""Inspect a Jac-emitted filter lambda for archetype-type identity.

Returns the archetype class name if the lambda is a pure `isinstance(i, T)`
check (or an Archetype instance acting as an identity filter). Returns None
when the filter is None or non-trivial (predicates, comparisons, etc.)."""
def _filter_type_name(filt: (Callable[[Archetype], bool] | None)) -> (str | None);


"""Detect whether a filter lambda contains predicate ops beyond type checks.

Pure `isinstance(i, T)` checks compile to LOAD_GLOBAL + CALL_FUNCTION +
RETURN; predicates introduce LOAD_ATTR / COMPARE_OP / CONTAINS_OP / IS_OP.
Conservative on inspection failure: assume predicates present so we never
silently skip filtering."""
def _filter_has_predicates(filt: (Callable[[Archetype], bool] | None)) -> bool;


"""Materialize a list of UUIDs to NodeAnchors via `batch_get` (when the
backend supports it) or per-id `get`, applying an optional post_filter
and slice. Returns the anchors in input order."""
def _materialize_ids(
    mem: Memory,
    ids: list[UUID],
    post_filter: (Callable[[Archetype], bool] | None) = None,
    slc: (slice | None) = None
) -> list[NodeAnchor];


"""Resolve the root anchor that owns an `ObjectSpatialPath`'s origin.

Returns None when the origin is empty, the origin anchor isn't persistent,
or the owning root can't be loaded from `mem`. A None result just means
the caller can't use the index for this query."""
def _path_root_anchor(mem: Memory, path: ObjectSpatialPath) -> (NodeAnchor | None);
