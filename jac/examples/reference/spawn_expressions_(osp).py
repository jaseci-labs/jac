"""Spawn expressions (OSP): Walker instantiation with spawn operator."""

from __future__ import annotations
from jaclang.lib import (
    Node,
    OPath,
    Root,
    Walker,
    build_edge,
    connect,
    impl_patch_filename,
    on_entry,
    refs,
    root,
    spawn,
    visit,
)


class Counter(Walker):

    @on_entry
    @impl_patch_filename("spawn_expressions_(osp).jac")
    def count(self, here: Root) -> None:
        connect(left=here, right=NumberNode(value=10))
        connect(left=here, right=NumberNode(value=20))
        visit(self, refs(OPath(here).edge_out().visit()))


class NumberNode(Node):
    value: int = 0

    @on_entry
    @impl_patch_filename("spawn_expressions_(osp).jac")
    def process(self, visitor: Counter) -> None:
        print(f"Processing node with value: {self.value}")


spawn(Counter(), root())
spawn(root(), Counter())
