from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


class Creator(_.Walker):

    @_.entry
    def create(self, here: _.Root) -> None:
        end = here
        i = 0
        while i < 3:
            _.connect(end, (end := node_a(val=i)))
            i += 1

        _.connect(
            end,
            (end := node_a(val=i + 10)),
            edge=connector,
            conn_assign=(("value",), (i,)),
        )
        _.connect(
            (end := node_a(val=i + 10)),
            _.root(),
            edge=connector,
            conn_assign=(("value",), (i,)),
        )
        _.visit(self, _.refs(here))


class node_a(_.Node):
    val: int

    @_.entry
    def make_something(self, here: Creator) -> None:
        i = 0
        while i < 5:
            print(f"wlecome to {self}")
            i += 1


class connector(_.Edge):
    value: int = 10


_.spawn(_.root(), Creator())
