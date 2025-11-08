from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


class Visitor(_.Walker):

    @_.entry
    def self_destruct(self, here: _.Root) -> None:
        print("get's here")
        return _.disengage(self)
        print("but not here")


_.spawn(_.root(), Visitor())
