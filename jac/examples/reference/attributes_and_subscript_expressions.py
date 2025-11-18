"""Attributes and Subscript expressions: Index access, slicing, and member access."""

from __future__ import annotations
from jaclang.lib import Obj, field


class Sample(Obj):
    items: list = field(factory=lambda: [10, 20, 30, 40, 50])
    data: dict = field(factory=lambda: {"name": "Alice", "age": 30})
    value: int = 42


s = Sample()
val = s.value
item1 = s.items[0]
item2 = s.items[-1]
name = s.data["name"]
slice1 = s.items[1:4]
slice2 = s.items[:3]
slice3 = s.items[2:]
first_char = s.data["name"][0]
__jac_tmp: Sample | None
safe_val = __jac_tmp.value if (__jac_tmp := s) else None
optional_obj = None
null_safe1 = __jac_tmp.value if (__jac_tmp := optional_obj) else None
null_safe2 = __jac_tmp.items if (__jac_tmp := optional_obj) else None
obj_with_data = Sample()
nested_val = __jac_tmp.data if (__jac_tmp := obj_with_data) else None
another_none = None
safe_chain = (
    __jac_tmp.items
    if (__jac_tmp := (__jac_tmp.value if (__jac_tmp := another_none) else None))
    else None
)
valid_obj = Sample()
safe_on_valid = __jac_tmp.items if (__jac_tmp := valid_obj) else None
print(val, item1, item2, name, slice1, slice2, slice3, first_char, safe_val)
print("Null-safe:", null_safe1, null_safe2, nested_val, safe_chain, safe_on_valid)
