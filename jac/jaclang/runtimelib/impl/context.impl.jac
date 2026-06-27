"""Execution context implementations."""

import os;
import from dataclasses { MISSING }
import from typing { Callable, cast }
import from uuid { UUID }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib.memory { TieredMemory }

"""Initialize ExecutionContext."""
impl ExecutionContext.postinit -> None {
    import from jaclang.jac0core.runtime { JacRuntime }
    if self._parent is not None {
        # Per-request fork: share the parent's Memory backend and system
        # root. Only user_root / entry_node / call_state / reports become
        # request-local state (the ContextVar and field defaults above
        # already ensure they are not shared by reference).
        self.mem = self._parent.mem;
        self.system_root = self._parent.system_root;
        self.user_root = self._parent.user_root;
        self.entry_node = self._parent.entry_node;
        self.base_path_dir = self._parent.base_path_dir;
        self.full_target_path = self._parent.full_target_path;
        return;
    }
    # Snapshot app identity from the module-level bootstrap seeds when
    # the caller did not pass explicit values. Doing the snapshot here —
    # rather than reading the seeds later from `get_name`/`get_db_path`
    # — is what locks in this ctx's persistence path at construction
    # time, immune to later seed mutations by sibling clients.
    if self.base_path_dir is None {
        self.base_path_dir = JacRuntime.get_base_path_dir();
    }
    if self.full_target_path is None {
        self.full_target_path = JacRuntime.get_full_target_path();
    }
    # Create TieredMemory - persistence only enabled if base_path_dir is
    # explicitly set. If base_path_dir is None, no L3 persistence (faster
    # for tests).
    self.mem = TieredMemory(
        base_path=self.base_path_dir, target_path=self.full_target_path
    );
    # Try to load system root from storage (TieredMemory handles L1/L3 lookup)
    system_root = cast((NodeAnchor | None), self.mem.get(UUID(Con.SUPER_ROOT_UUID)));
    # Create system root if not found
    if not isinstance(system_root, NodeAnchor) {
        system_root = cast(NodeAnchor, Root().__jac__);
        system_root.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root);
    }
    self.system_root = system_root;
    # Default user_root and entry_node to system_root
    self.user_root = self.system_root;
    self.entry_node = self.system_root;
}

"""Get anchor by ID or raise error."""
impl ExecutionContext._get_anchor(anchor_id: str) -> NodeAnchor {
    id = UUID(anchor_id);
    # TieredMemory handles L1/L3 lookup with read-through caching
    anchor = self.mem.get(id);
    if not isinstance(anchor, NodeAnchor) {
        raise ValueError(f"Invalid anchor id {anchor_id} !");
    }
    return anchor;
}

"""Set user root for permission boundary and default entry point.

This sets which user is making the request. All permission checks
and new node ownership will use this root.
"""
impl ExecutionContext.set_user_root(root_id: str) -> None {
    self.user_root = self._get_anchor(root_id);
    # Default entry_node to user_root unless explicitly set otherwise
    self.entry_node = self.user_root;
}

"""Set entry node for walker traversal start point."""
impl ExecutionContext.set_entry_node(entry_node: (str | None)) -> None {
    self.entry_node = self._get_anchor(entry_node) if entry_node else self.user_root;
}

"""Close current ExecutionContext."""
impl ExecutionContext.close -> None {
    # Per-request fork: do not close the shared Memory backend — it is
    # owned by the parent ctx and must outlive this request.
    if self._parent is not None {
        return;
    }
    # TieredMemory handles syncing to persistence and closing all tiers
    self.mem.close();
    # Fire any on_commit effects flushed by close()'s commit backstop. This
    # covers CLI / library flows (jac run) that rely on close() rather than an
    # explicit commit()/acommit(); a no-op if an earlier commit already drained.
    self.run_pending_effects();
}

"""Register a callback to run after the next successful commit.

Backs the `on_commit(...)` ambient builtin. Callbacks are deferred
external effects: they run only if the unit of work actually flushes,
and exactly once per registration, so a request that aborts before
committing never fires them.
"""
impl ExecutionContext.on_commit(callback: Callable) -> None {
    self.pending_effects.append(callback);
}

"""Drain and run queued post-commit effects.

Snapshot-then-clear before running so an effect that itself registers
another effect enqueues it for the next drain rather than extending
this one. A failing effect is logged and skipped: it neither aborts the
commit nor blocks the remaining effects.
"""
impl ExecutionContext.run_pending_effects -> None {
    if not self.pending_effects {
        return;
    }
    effects = self.pending_effects;
    self.pending_effects = [];
    for effect in effects {
        try {
            effect();
        } except Exception as e {
            logger.error(f"on_commit effect failed: {e}");
        }
    }
}

"""Read-set OCC: snapshot the version of each node a request reads an
out-traversal from, so the collect pass can promote it to a commit-time CAS.

Recorded by `refs` *before* the planner/edge-walk split, so a topology-index
fast path (which never reaches `edges_to_nodes`) still takes the dependency.
First read wins (`setdefault`): a later read in the same request never
overwrites the version originally observed.
"""
impl ExecutionContext.note_traversal_reads(origins: list[NodeAnchor]) -> None {
    for anchor in origins {
        if isinstance(anchor, NodeAnchor) {
            self.read_versions.setdefault(anchor.id, anchor.version);
        }
    }
}

"""Get current user's root."""
impl ExecutionContext.get_root -> Root {
    return cast(Root, self.user_root.archetype);
}

"""Async mirror of _get_anchor — goes through the async Memory surface."""
impl ExecutionContext._aget_anchor(anchor_id: str) -> NodeAnchor {
    id = UUID(anchor_id);
    anchor = await self.mem.aget(id);
    if not isinstance(anchor, NodeAnchor) {
        raise ValueError(f"Invalid anchor id {anchor_id} !");
    }
    return anchor;
}

"""Async mirror of set_user_root — resolves root via async Memory."""
impl ExecutionContext.aset_user_root(root_id: str) -> None {
    self.user_root = await self._aget_anchor(root_id);
    self.entry_node = self.user_root;
}
