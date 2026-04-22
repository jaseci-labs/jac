"""Execution context for Jac Language."""

import from contextvars { ContextVar }
import from dataclasses { MISSING }
import from queue { Queue }
import from typing { Any, cast }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib.memory { Memory, TieredMemory }

glob __all__ = ['ExecutionContext'];

"""Call State for managing function, spawn calls.

`reports` is a thread-safe `queue.Queue` so sync walkers running inside
`asyncio.to_thread` can call `put_nowait` from the worker thread safely.
The collector drains synchronously after the walker joins (see
`ExecutionManager.report_collector`), so the queue is never contended by
a concurrent getter — we just need put-from-thread to be correct.
"""
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
    has mem: Memory by postinit,
        reports: list[Any] = [],
        custom: Any = MISSING,
        system_root: NodeAnchor by postinit,
        user_root: NodeAnchor by postinit,
        entry_node: NodeAnchor by postinit,
        call_state: ContextVar[CallState] = ContextVar('call_state'),
        # Per-request fork support. When `_parent` is set, postinit skips
        # creating fresh Memory/system_root and instead shares them with
        # the parent ctx. This lets the server stamp out lightweight
        # per-request contexts whose `user_root` / `entry_node` mutations
        # are isolated from concurrent requests (via `_request_context`
        # ContextVar) while reusing the heavy, shared Memory backend.
        _parent: (ExecutionContext | None) = None;

    def postinit -> None;
    def _get_anchor(anchor_id: str) -> NodeAnchor;
    def set_user_root(root_id: str) -> None;
    def set_entry_node(entry_node: (str | None)) -> None;
    def close -> None;
    def get_root -> Root;
    # Async mirrors — resolve root / entry via the async Memory surface so
    # the calling event loop is not blocked on L3 reads.
    async def _aget_anchor(anchor_id: str) -> NodeAnchor;
    async def aset_user_root(root_id: str) -> None;
    async def aset_entry_node(entry_node: (str | None)) -> None;
}
