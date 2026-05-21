"""Topology index maintenance hooks.

These functions keep root topology indices in sync with graph mutations
(edge create/destroy, node save/destroy). All are no-ops when the
topology_index config flag is disabled.

Query planning lives in `jaclang.runtimelib.planner` — this module only
mutates the index in response to runtime events. The cleanup boundary is
explicit: anything that *reads* the index for a query goes through the
planner; anything that *writes* the index in response to a graph mutation
stays here.
"""

import from uuid { UUID }

"""Check if topology_index is enabled. The `JAC_TOPOLOGY_INDEX` env var
overrides the toml flag (truthy: 1 / true / yes / on)."""
def _is_enabled -> bool;

"""Get the root NodeAnchor that owns this anchor."""
def _get_root_anchor(anchor: any) -> any;

"""Get the archetype class name."""
def _type_name(`obj: object) -> str;

"""Get the user-defined MRO chain for a node/edge archetype, stopping at the
runtime base archetypes (Node/Edge/Walker/Archetype/object). Concrete type
appears at index 0."""
def _get_type_mro(`obj: object) -> list[str];

"""Called after an edge is created between source and target."""
def on_edge_created(source: any, target: any, `edge: any) -> None;

"""Called when an edge is destroyed."""
def on_edge_destroyed(source: any, target: any, `edge: any) -> None;

"""Called when a node is saved/persisted. Ensures it's in the root's index."""
def on_node_saved(node_anchor: any) -> None;

"""Called when a node is destroyed."""
def on_node_destroyed(node_anchor: any) -> None;
