"""Bug #ANY-1: typing.Any attribute access incorrectly raises E1030.

TypeBase.is_any_type() missed ClassType-wrapped typing.Any. E1030 guards
used lookup_type.is_any_type() (simple) instead of self.is_any_type()
(TypeEvaluator, which also checks prefetch.any_class). Fix: use self.is_any_type().
"""

import from typing { Any }

def test_any_attr_access(val: Any) -> None {
    _ = val.origin;  # <-- Ok (was E1030 before fix)
    _ = val.id;  # <-- Ok
    _ = val.anything;  # <-- Ok
    val.method();  # <-- Ok
}

def test_any_subscript(d: Any) -> None {
    _ = d.get('key');  # <-- Ok
}
