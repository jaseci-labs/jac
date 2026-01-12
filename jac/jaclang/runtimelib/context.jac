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
class ExecutionContext {
    has mem: Memory,
        reports: list[Any],
        custom: Any,
        system_root: NodeAnchor,
        entry_node: NodeAnchor,
        root_state: NodeAnchor;

    def init(
        self: ExecutionContext,
        session: (str | None) = None,
        <>root: (str | None) = None
    ) -> None;

    def _get_anchor(self: ExecutionContext, anchor_id: str) -> NodeAnchor;
    def set_entry_node(self: ExecutionContext, entry_node: (str | None)) -> None;
    def close(self: ExecutionContext) -> None;
    def get_root(self: ExecutionContext) -> Root;
}
