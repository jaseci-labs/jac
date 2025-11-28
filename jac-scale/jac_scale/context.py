from dataclasses import MISSING
from typing import Any
from uuid import UUID

from jac_scale.memory_hierarchy import MultiHierarchyMemory
from jaclang.compiler.constant import Constants as Con
from jaclang.runtimelib.constructs import NodeAnchor, Root
from jaclang.runtimelib.runtime import ExecutionContext


class JScaleExecutionContext(ExecutionContext):
    """Jac Scale Execution Context with custom memory backend."""

    def __init__(
        self,
        session: str | None = None,
        root: str | None = None,
    ) -> None:
        """Initialize JScaleExecutionContext."""
        self.mem: MultiHierarchyMemory = MultiHierarchyMemory()
        self.reports: list[Any] = []
        self.custom: Any = MISSING
        self.system_root = self.mem.find_by_id(UUID(Con.SUPER_ROOT_UUID))
        if not isinstance(self.system_root, NodeAnchor):
            self.system_root = Root().__jac__
            self.system_root.id = UUID(Con.SUPER_ROOT_UUID)
            self.mem.set(self.system_root)
        self.entry_node = self.root_state = (
            self._get_anchor(root) if root else self.system_root
        )
