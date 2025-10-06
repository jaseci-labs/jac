from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Reporter(_jl.Walker):

    @_jl.entry
    def process(self, here: _jl.Root) -> None:
        _jl.report(42)
        _jl.report('hello')
        _jl.report(10 + 20)
        x = 100
        _jl.report(x)
        _jl.report([1, 2, 3])
        _jl.report({'key': 'value', 'number': 123})
        _jl.report({'result': 5 * 10, 'status': 'ok'})
        _jl.disengage(self)
        return
w = Reporter()
_jl.spawn(_jl.root(), w)
