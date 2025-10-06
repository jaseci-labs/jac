"""Object spatial spawn expressions: Walker instantiation with spawn operator."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Counter(_jl.Walker):

    @_jl.entry
    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/object_spatial_spawn_expressions.jac')
    def count(self, here: _jl.Root) -> None:
        _jl.connect(left=here, right=NumberNode(value=10))
        _jl.connect(left=here, right=NumberNode(value=20))
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class NumberNode(_jl.Node):
    value: int = 0

    @_jl.entry
    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/object_spatial_spawn_expressions.jac')
    def process(self, visitor: Counter) -> None:
        print(f'Processing node with value: {self.value}')
_jl.spawn(Counter(), _jl.root())
_jl.spawn(_jl.root(), Counter())
