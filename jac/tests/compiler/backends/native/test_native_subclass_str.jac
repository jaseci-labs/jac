"""`str()` of a value typed as a base class runs the subclass's `__str__`.

When only subclasses define `__str__`, the base has no vtable slot for it and
the lowering fell back to the default `<Base object at ...>` text. It now
compares the object's vtable against each subclass that defines `__str__` and
calls the match, keeping the default text for subclasses without one.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "str of a base-typed value dispatches to the subclass __str__" {
    (eng, _ir) = compile_native("subclass_str_dispatch.jac");
    assert get_func(eng, "str_through_base", ctypes.c_int64)() == 3;
    assert get_func(eng, "base_without_str_keeps_default_repr", ctypes.c_int64)() == 1;
}
