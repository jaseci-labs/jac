from dataclasses import MISSING
from typing import Any
from uuid import UUID

from jac_scale.memory_hierarchy import MultiHierarchyMemory
from jaclang.compiler.constant import Constants as Con
from jaclang.runtimelib.constructs import Anchor, NodeAnchor, Root
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
        system_root_anchor: Anchor | None = self.mem.find_by_id(
            UUID(Con.SUPER_ROOT_UUID)
        )
        if not isinstance(system_root_anchor, NodeAnchor):
            system_root_anchor = Root().__jac__
            system_root_anchor.id = UUID(Con.SUPER_ROOT_UUID)
            self.mem.set(system_root_anchor)
        self.system_root = system_root_anchor
        self.entry_node = self.root_state = (
            self._get_anchor(root) if root else self.system_root
        )
