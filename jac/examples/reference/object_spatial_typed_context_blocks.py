from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


class Producer(_.Walker):

    @_.entry
    def produce(self, here: _.Root) -> None:
        end = here
        i = 0
        while i < 3:
            _.connect(end, (end := Product(number=i + 1)))
            i += 1
        _.visit(self, _.refs(here))


class Product(_.Node):
    number: int

    @_.entry
    def make(self, here: Producer) -> None:
        print(f"Hi, I am {self} returning a String")
        _.visit(here, _.refs(self))


_.spawn(_.root(), Producer())
