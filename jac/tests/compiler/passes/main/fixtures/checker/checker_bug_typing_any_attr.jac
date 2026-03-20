"""Bug #ANY-1: typing.Any attribute access incorrectly raises E1030.

TypeBase.is_any_type() missed ClassType-wrapped typing.Any. E1030 guards
used lookup_type.is_any_type() (simple) instead of self.is_any_type()
(TypeEvaluator, which also checks prefetch.any_class). Fix: use self.is_any_type().

Additionally, attribute access on Any must return Any (not Unknown), so that
chained access like val.foo.bar.baz works without E1032 errors.
"""

import from typing { Any }

def test_any_attr_access(val: Any) -> None {
    _ = val.origin;  # <-- Ok (was E1030 before fix)
    _ = val.id;  # <-- Ok
    _ = val.anything;  # <-- Ok
    _ = val.anything.nested;  # <-- Ok (chained access, returns Any)
    _ = val.a.b.c.d;  # <-- Ok (deep chained access)
    val.method();  # <-- Ok
}

def test_any_subscript(val: Any) -> None {
    _ = val.get('key');  # <-- Ok
    _ = val[0];  # <-- Ok (subscript returns Any)
    _ = val[0].attr;  # <-- Ok (subscript then attr)
    _ = val['key'].nested[0].deep;  # <-- Ok (mixed access)
}

def test_any_calls(val: Any) -> None {
    _ = val();  # <-- Ok (call returns Any)
    _ = val().attr;  # <-- Ok (call then attr)
    _ = val.method().result;  # <-- Ok (method call then attr)
    _ = val()()[0].foo.bar();  # <-- Ok (complex chain)
}

# Contrast: object type does NOT allow arbitrary attribute access (unlike Any)
def test_object_attr_access(val: object) -> None {
    val.__doc__;  # <-- Ok (object has __doc__)
    val.nonexistent;  # <-- Error: object has no attribute "nonexistent"
}
