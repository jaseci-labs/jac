"""Execution context implementations."""

import from dataclasses { MISSING }
import from typing { Any, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.memory { TieredMemory }

"""Initialize ExecutionContext."""
impl ExecutionContext.init(
    self: ExecutionContext, session: (str | None) = None, <>root: (str | None) = None
) -> None {
    # Create TieredMemory with optional persistence
    self.mem = TieredMemory(session=session);
    self.reports = [];
    self.custom = MISSING;
    # Try to load system root from storage (TieredMemory handles L1/L3 lookup)
    system_root = cast((NodeAnchor | None), self.mem.get(UUID(Con.SUPER_ROOT_UUID)));
    # Create system root if not found
    if not isinstance(system_root, NodeAnchor) {
        system_root = cast(NodeAnchor, Root().__jac__);
        system_root.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root);
    }
    self.system_root = system_root;
    self.entry_node = self.root_state=(
        self._get_anchor(<>root) if <>root else self.system_root
    );
}

"""Get anchor by ID or raise error."""
impl ExecutionContext._get_anchor(self: ExecutionContext, anchor_id: str) -> NodeAnchor {
    id = UUID(anchor_id);
    # TieredMemory handles L1/L3 lookup with read-through caching
    anchor = self.mem.get(id);
    if not isinstance(anchor, NodeAnchor) {
        raise ValueError(f"Invalid anchor id {anchor_id} !") ;
    }
    return anchor;
}

"""Override entry node."""
impl ExecutionContext.set_entry_node(
    self: ExecutionContext, entry_node: (str | None)
) -> None {
    self.entry_node = self._get_anchor(entry_node) if entry_node else self.root_state;
}

"""Close current ExecutionContext."""
impl ExecutionContext.close(self: ExecutionContext) -> None {
    # TieredMemory handles syncing to persistence and closing all tiers
    self.mem.close();
}

"""Get current root."""
impl ExecutionContext.get_root(self: ExecutionContext) -> Root {
    return cast(Root, self.root_state.archetype);
}
