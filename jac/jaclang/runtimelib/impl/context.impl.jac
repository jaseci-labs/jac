"""Execution context implementations."""

import from dataclasses { MISSING }
import from typing { Any, cast }
import from uuid { UUID }

import from jaclang.pycore.archetype { Anchor, NodeAnchor, Root }
import from jaclang.pycore.constant { Constants as Con }
import from jaclang.runtimelib.memory { Memory }
import from jaclang.runtimelib.storage { ShelfStorage }

"""Initialize ExecutionContext."""
impl ExecutionContext.init(
    self: ExecutionContext, session: (str | None) = None, <>root: (str | None) = None
) -> None {
    self.mem = Memory[(UUID, Anchor)]();
    self.persistence = ShelfStorage(session) if session else None;
    self.reports = [];
    self.custom = MISSING;

    # Try to load system root from persistence first
    system_root: (NodeAnchor | None) = None;
    if self.persistence {
        system_root = cast((NodeAnchor | None), self.persistence.get(UUID(Con.SUPER_ROOT_UUID)));
        if isinstance(system_root, NodeAnchor) {
            self.mem.put(system_root);
        }
    }

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
    anchor = self.mem.get(id);

    # Try loading from persistence if not in memory
    if not anchor and self.persistence {
        anchor = self.persistence.get(id);
        if isinstance(anchor, NodeAnchor) {
            self.mem.put(anchor);
        }
    }

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
    # Sync memory to persistence before closing
    if self.persistence {
        self.persistence.sync_from_memory(self.mem.get_mem(), self.mem.get_gc());
        self.persistence.close();
    }
    self.mem.close();
}

"""Get current root."""
impl ExecutionContext.get_root(self: ExecutionContext) -> Root {
    return cast(Root, self.root_state.archetype);
}
