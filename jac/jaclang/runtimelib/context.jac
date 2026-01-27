"""Execution context for Jac Language."""

import from asyncio { Queue }
import from contextvars { ContextVar }
import from dataclasses { MISSING }
import from typing { Any, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.memory { Memory, TieredMemory }

glob __all__ = ['ExecutionContext'];

"""Call State for managing function, spawn calls."""
obj CallState {
    has reports: Queue = Queue(),
        _sentinel: object = object();
}

"""Execution Context.

The `mem` field is a Memory implementation (typically TieredMemory) that provides
a unified interface to all storage tiers. TieredMemory handles read-through
caching and write-through persistence with access control internally.

Fields:
- system_root: The global system root (superuser access, fixed UUID)
- user_root: The current user's root node (for permission checks and ownership)
- entry_node: Where walkers start traversal (defaults to user_root)
"""
obj ExecutionContext {
    has mem: Memory | None = None,
        reports: list[Any] = [],
        custom: Any = MISSING,
        system_root: NodeAnchor | None = None,
        user_root: NodeAnchor | None = None,
        entry_node: NodeAnchor | None = None,
        call_state: ContextVar[CallState] = ContextVar(
            'call_state', default=CallState()
        );

    def postinit -> None;
    def _get_anchor(anchor_id: str) -> NodeAnchor;
    def set_user_root(root_id: str) -> None;
    def set_entry_node(entry_node: (str | None)) -> None;
    def close -> None;
    def get_root -> Root;
}
