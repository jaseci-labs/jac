"""Execution context for Jac Language."""

import from dataclasses { MISSING }
import from typing { Any, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.memory { Memory, TieredMemory }

glob __all__ = ['ExecutionContext'];

"""Execution Context.

The `mem` field is a Memory implementation (typically TieredMemory) that provides
a unified interface to all storage tiers. TieredMemory handles read-through
caching and write-through persistence with access control internally.
"""
obj ExecutionContext {
    has mem: Memory | None = None,
        reports: list[Any] = [],
        custom: Any = MISSING,
        system_root: NodeAnchor | None = None,
        entry_node: NodeAnchor | None = None,
        root_state: NodeAnchor | None = None,
        session: (str | None) = None,
        <>root: (str | None) = None;

    def postinit -> None;
    def _get_anchor(anchor_id: str) -> NodeAnchor;
    def set_entry_node(entry_node: (str | None)) -> None;
    def close -> None;
    def get_root -> Root;
}
