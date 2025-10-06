from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Visitor(_jl.Walker):

    @_jl.entry
    def self_destruct(self, here: _jl.Root) -> None:
        print("get's here")
        _jl.disengage(self)
        return
        print('but not here')
_jl.spawn(_jl.root(), Visitor())
