"""Topology index maintenance and query planning utilities.

These functions are called from the Jac runtime to keep root topology
indices in sync with graph mutations. All functions are no-ops when the
topology_index config flag is disabled.
"""

import inspect;
import from collections.abc { Callable }
import from typing { Any }
import from uuid { UUID }

"""Check if topology_index is enabled. The `JAC_TOPOLOGY_INDEX` env var
overrides the toml flag (truthy: 1 / true / yes / on)."""
def _is_enabled -> bool;

"""Get the root NodeAnchor that owns this anchor."""
def _get_root_anchor(anchor: Any) -> Any;

"""Get the archetype class name."""
def _type_name(`obj: object) -> str;

"""Get the user-defined MRO chain for a node/edge archetype, stopping at the
runtime base archetypes (Node/Edge/Walker/Archetype/object). Concrete type
appears at index 0."""
def _get_type_mro(`obj: object) -> list[str];

"""Called after an edge is created between source and target."""
def on_edge_created(source: Any, target: Any, `edge: Any) -> None;

"""Called when an edge is destroyed."""
def on_edge_destroyed(source: Any, target: Any, `edge: Any) -> None;

"""Called when a node is saved/persisted. Ensures it's in the root's index."""
def on_node_saved(node_anchor: Any) -> None;

"""Called when a node is destroyed."""
def on_node_destroyed(node_anchor: Any) -> None;

"""Try to extract the type name from a filter lambda."""
def _extract_type_name_from_filter(filt: (Callable | None)) -> (str | None);

"""Detect if a filter lambda has predicates beyond a pure type check.

The topology index can only resolve type-only filters; predicates on
attributes must be evaluated by the linear path. Returns True if the
filter does anything beyond `isinstance(i, T)`, including the
conservative-on-failure case where the lambda cannot be inspected.
"""
def _filter_has_predicates(filt: (Callable | None)) -> bool;

"""Use the topology index to resolve which node UUIDs will survive
the type-only filters in a path chain. Returns set of target UUIDs
if planning succeeded, or None to fall back to normal approach."""
def plan_query(path: Any) -> (set[UUID] | None);

"""Like `plan_query` but for sliced (paginated) traversals. Returns a list of
target UUIDs in canonical edge-insertion order with the slice already applied,
or None when pushdown is not eligible (multi-hop, predicate filters, no index,
non-persistent origin, or topology_index disabled)."""
def plan_query_ordered(path: Any, slc: slice) -> (list[UUID] | None);

"""Load nodes by UUID set, preserving edge-list order from origin nodes."""
def batch_load_nodes(node_ids: set[UUID], origin: (list | None) = None) -> list[Any];

"""Load nodes by an ordered UUID list, preserving the input order. Used by
the slice-pushdown fast path which has already determined the bounded set."""
def batch_load_nodes_by_ids(node_ids: list[UUID]) -> list[Any];
