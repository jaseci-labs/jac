from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


class Adder(_.Walker):

    @_.entry
    def do(self, here: _.Root) -> None:
        _.connect(here, node_a())
        _.visit(self, _.refs(here))


class node_a(_.Node):
    x: int = 0
    y: int = 0

    @_.entry
    def add(self, here: Adder) -> None:
        self.x = 550
        self.y = 450
        print(int(self.x) + int(self.y))


_.spawn(Adder(), _.root())
