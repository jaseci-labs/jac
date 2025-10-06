from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Producer(_jl.Walker):

    @_jl.entry
    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/object_spatial_typed_context_blocks.jac')
    def produce(self, here: _jl.Root) -> None:
        end = here
        i = 0
        while i < 3:
            _jl.connect(left=end, right=(end := Product(number=i + 1)))
            i += 1
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class Product(_jl.Node):
    number: int

    @_jl.entry
    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/object_spatial_typed_context_blocks.jac')
    def make(self, visitor: Producer) -> None:
        print(f'Hi, I am {self} returning a String')
        _jl.visit(visitor, _jl.refs(_jl.Path(self)._out().visit()))
_jl.spawn(_jl.root(), Producer())
