"""Per-hop edge-traversal resolver.

The runtime entry point `refs()` walks an `ObjectSpatialPath` by folding over
the chain of hops. Each hop is resolved by a single, uniform `resolve_hop`
call that *always succeeds*: it tries the topology index first, and falls
back to a single-hop anchor walk for any case the index can't cover
(predicate filters on this hop, foreign-root IDs in the input, no usable
index, or `resolve_chain` declining the hop). There is no chain-level bail
and no global slow-loop fallback in `refs()` — the only fallback is per-hop.

`resolve_path_anchors` therefore always returns a `list[NodeAnchor]`; an
empty list means "the query has zero matches," never "fast path declined."
This eliminates the all-or-nothing split between today's `execute_path` and
the slow `edges_to_nodes` loop: every hop locally picks the best strategy
without forfeiting index narrowing on the other hops.

Position-aware concerns (which hop receives `slc`, whether the
canonical-edge-walk order is required for an unsliced single-hop call) live
in `resolve_path_anchors`. `resolve_hop` itself is uniform across positions.
"""

import os;
import logging;
import from uuid { UUID }
import from collections.abc { Callable }

import from jaclang.jac0core.archetype {
    Archetype,
    NodeAnchor,
    NodeArchetype,
    ObjectSpatialDestination,
    ObjectSpatialPath
}
import from jaclang.runtimelib.memory { Memory }
import from jaclang.runtimelib.query_plan { QueryPlan }
import from jaclang.runtimelib.topology_index { TopologyIndex }

glob logger = logging.getLogger(__name__),
     __all__ = ['ChainHop', 'resolve_hop', 'resolve_path_anchors'];


"""One hop's data, carrying both the type names the topology_index consumes
and the raw `ObjectSpatialDestination` whose callable filters the walk path
needs. Two views of the same hop fused into one struct so the per-hop fold
has a single parameter shape regardless of which dispatch fires."""
obj ChainHop {
    has dest: ObjectSpatialDestination,
        edge_type: (str | None) = None,
        node_type: (str | None) = None,
        direction: int = 2;
}


"""Resolve a single hop, always returning a result.

Returns a `set[UUID]` of target node IDs when `slc is None` (intermediate
hop), or a `list[UUID]` already sliced in canonical edge-walk order when
`slc is not None` (final hop with ordered semantics).

Tries the topology index when the hop has no predicate filters, has a root
anchor, and the input IDs are all known to that root's index. Falls back to
a single-hop `edges_to_nodes` walk for any other shape — the walk crosses
roots transparently, applies callable filters, and works on transient
anchors. Never returns `None`."""
def resolve_hop(
    mem: Memory,
    current_ids: set[UUID],
    hop: ChainHop,
    idx: (TopologyIndex | None),
    hop_idx: int,
    slc: (slice | None) = None
) -> (set[UUID] | list[UUID]);


"""High-level path entry point. Walks the path's hop chain via the per-hop
`resolve_hop` fold and returns materialized `NodeAnchor`s.

Always returns a list. Empty for empty-origin or zero-match queries; never
`None`. Transient origins (anchors not in `mem`) run an inline archetype
walk because the per-hop fold's batch_get materialization assumes anchors
are loadable from `mem`."""
def resolve_path_anchors(
    mem: Memory, path: ObjectSpatialPath, slc: (slice | None) = None
) -> list[NodeAnchor];
