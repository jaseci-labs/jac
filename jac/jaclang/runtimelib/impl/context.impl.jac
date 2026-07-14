import os;
import from dataclasses { MISSING }
import from typing { Callable, cast }
import from uuid { UUID }

import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib.exceptions { MissingAnchorError }
import from jaclang.runtimelib.memory { TieredMemory }

impl ExecutionContext.postinit -> None {
    import from jaclang.jac0core.runtime { JacRuntime }
    if self._parent is not None {
        self.mem = self._parent.mem;
        self.system_root = self._parent.system_root;
        self.user_root = self._parent.user_root;
        self.entry_node = self._parent.entry_node;
        self.base_path_dir = self._parent.base_path_dir;
        self.full_target_path = self._parent.full_target_path;
        return;
    }

    if self.base_path_dir is None {
        self.base_path_dir = JacRuntime.get_base_path_dir();
    }
    if self.full_target_path is None {
        self.full_target_path = JacRuntime.get_full_target_path();
    }

    self.mem = TieredMemory(
        base_path=self.base_path_dir, target_path=self.full_target_path
    );

    system_root = cast((NodeAnchor | None), self.mem.get(UUID(Con.SUPER_ROOT_UUID)));

    if not isinstance(system_root, NodeAnchor) {
        system_root = cast(NodeAnchor, Root().__jac__);
        system_root.id = UUID(Con.SUPER_ROOT_UUID);
        self.mem.put(system_root);
    }
    self.system_root = system_root;

    self.user_root = self.system_root;
    self.entry_node = self.system_root;
}

impl ExecutionContext._get_anchor(anchor_id: str) -> NodeAnchor {
    id = UUID(anchor_id);

    anchor = self.mem.get(id);
    if not isinstance(anchor, NodeAnchor) {
        raise MissingAnchorError(anchor_id=anchor_id);
    }
    return anchor;
}

impl ExecutionContext.set_user_root(root_id: str) -> None {
    self.user_root = self._get_anchor(root_id);

    self.entry_node = self.user_root;
}

impl ExecutionContext.set_entry_node(entry_node: (str | None)) -> None {
    self.entry_node = self._get_anchor(entry_node) if entry_node else self.user_root;
}

impl ExecutionContext.close -> None {
    if self._parent is not None {
        return;
    }

    self.mem.close();

    self.run_pending_effects();
}

impl ExecutionContext.on_commit(callback: Callable) -> None {
    self.pending_effects.append(callback);
}

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

impl ExecutionContext.note_traversal_reads(origins: list[NodeAnchor]) -> None {
    for anchor in origins {
        if isinstance(anchor, NodeAnchor) {
            self.read_versions.setdefault(anchor.id, anchor.version);
        }
    }
}

impl ExecutionContext.get_root -> Root {
    return cast(Root, self.user_root.archetype);
}

impl ExecutionContext._aget_anchor(anchor_id: str) -> NodeAnchor {
    id = UUID(anchor_id);
    anchor = await self.mem.aget(id);
    if not isinstance(anchor, NodeAnchor) {
        raise MissingAnchorError(anchor_id=anchor_id);
    }
    return anchor;
}

impl ExecutionContext.aset_user_root(root_id: str) -> None {
    self.user_root = await self._aget_anchor(root_id);
    self.entry_node = self.user_root;
}
