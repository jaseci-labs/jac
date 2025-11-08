from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


class Creator(_.Walker):

    @_.entry
    def func2(self, here: _.Root) -> None:
        end = here
        i = 0
        while i < 5:
            _.connect(end, (end := node_1(val=i + 1)))
            i += 1
        _.visit(self, _.refs(here))


class node_1(_.Node):
    val: int

    @_.entry
    def func_1(self, here: Creator) -> None:
        print("visiting ", self)
        _.visit(here, _.refs(self))


_.spawn(_.root(), Creator())
_.spawn(_.root(), Creator())
