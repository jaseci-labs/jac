"""Subscripted and dotted expressions: Index access, slicing, and member access."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class Sample(_jl.Obj):
    items: list = _jl.field(factory=lambda: [10, 20, 30, 40, 50])
    data: dict = _jl.field(factory=lambda: {'name': 'Alice', 'age': 30})
    value: int = 42
s = Sample()
val = s.value
item1 = s.items[0]
item2 = s.items[-1]
name = s.data['name']
slice1 = s.items[1:4]
slice2 = s.items[:3]
slice3 = s.items[2:]
first_char = s.data['name'][0]
safe_val = __jac_tmp.value if (__jac_tmp := s) else None
print(val, item1, item2, name, slice1, slice2, slice3, first_char, safe_val)
