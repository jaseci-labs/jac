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
import from functools { lru_cache }

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


"""Hashable carrier so `lru_cache` can key on a function's `__code__` plus
the *type-valued* captures in its closure, while still passing the function
itself through to the cached implementation for `inspect.getclosurevars`.

Naively keying on `__code__` alone is incorrect under a shared-helper
codegen pattern such as:

    def mk_filter(arch): return lambda x: isinstance(x, arch);
    f_a = mk_filter(TypeA);
    f_b = mk_filter(TypeB);

Both `f_a` and `f_b` would share `__code__` but capture *different*
archetype classes; a code-only cache would silently return the first
result for every subsequent call. Today's Jac codegen doesn't emit that
pattern, but nothing in the planner enforces it.

Including the closure's type-valued contents (Archetype subclasses are
always classes, so we only need to capture `type` cells) makes the key
faithful to the computation: the cache only hits when both the bytecode
and the captured class set match. The closure walk to extract those cells
is a constant-time touch of `filt.__closure__`, not the expensive
`inspect.getclosurevars` walk."""
obj _CodeKey {
    has filt: any,
        code: any by postinit,
        closure_types: tuple by postinit;

    def postinit -> None;
    def __hash__ -> int;
    def __eq__(other: object) -> bool;
}


"""Cached impl keyed by a `_CodeKey` wrapper whose hash is the function's
`__code__` plus its type-valued closure captures. Two lambdas with the
same source and same captures collapse to one cache entry.

After the closurevars walk completes we drop the strong reference to the
lambda (`key.filt = None`). Cache hits only ever compare hashes and run
`__eq__`, neither of which touches `filt` — so dropping it bounds the
cache's per-entry retention to the code object + the captured class
tuple. Without this, a long-running process that exercises many distinct
filter source-sites would accumulate live lambdas (and their closures)
forever under `lru_cache(maxsize=None)`.

Definition stays inline (interface + body together) because the
`@lru_cache` decorator only binds reliably when the body is in the same
file as the `def` — Jac's impl-annex splitting drops the decorator
otherwise."""
@lru_cache(maxsize=None)
def _filter_type_name_by_code(key: _CodeKey) -> (str | None) {
    result: (str | None) = None;
    try {
        closure = inspect.getclosurevars(key.filt);
        for val in `list(closure.nonlocals.values()) + `list(
            closure.globals.values()
        ) {
            if isinstance(val, `type) and issubclass(val, Archetype) {
                result = val.__name__;
                break;
            }
        }
    } except Exception {
        ;
    }
    # Cache hits don't need the lambda; release it so the closure can GC.
    key.filt = None;
    return result;
}


"""Cached impl keyed on the bytecode object directly. `dis.get_instructions`
accepts a code object, so no function-object juggling needed here.

Inline for the same decorator-binding reason as `_filter_type_name_by_code`."""
@lru_cache(maxsize=None)
def _filter_has_predicates_by_code(code: any) -> bool {
    try {
        opcodes = {instr.opname for instr in dis.get_instructions(code)};
    } except (TypeError, AttributeError, ValueError) {
        return True;
    }
    return bool(opcodes & {'LOAD_ATTR', 'COMPARE_OP', 'CONTAINS_OP', 'IS_OP'});
}


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
