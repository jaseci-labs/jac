"""Execution context implementations."""

import os;
import from dataclasses { MISSING }
import from typing { Any, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.memory { TieredMemory }

"""Initialize ExecutionContext."""
impl ExecutionContext.postinit -> None {
    import from jaclang.pycore.runtime { JacRuntime }
    # Create TieredMemory - persistence only enabled if base_path_dir is explicitly set
    # If base_path_dir is None, no L3 persistence (faster for tests)
    self.mem = TieredMemory(base_path=JacRuntime.base_path_dir);
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
        raise ValueError(f"Invalid anchor id {anchor_id} !") ;
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
    # TieredMemory handles syncing to persistence and closing all tiers
    self.mem.close();
}

"""Get current user's root."""
impl ExecutionContext.get_root -> Root {
    return cast(Root, self.user_root.archetype);
}
