from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


class Visitor(_.Walker):

    @_.entry
    def travel(self, here: _.Root) -> None:
        if not _.visit(self, _.refs(here)):
            _.visit(self, _.root())
            return _.disengage()


class item(_.Node):

    @_.entry
    def speak(self, here: Visitor) -> None:
        print("Hey There!!!")


i = 0
while i < 5:
    _.connect(_.root(), item())
    i += 1

_.spawn(_.root(), Visitor())
