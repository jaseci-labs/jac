"""A method read through an instance is a bound method value.

`f = self.tr` and passing `self.tr` as a `Callable` argument had no native
lowering: the method was refused, or the value came out as a null callable
that crashed when called. It now lowers to a closure over the receiver, so it
dispatches like any call through the receiver (overrides included), sees later
changes to the receiver, and can be stored and called later.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "bound method values behave like Python's" {
    (eng, _ir) = compile_native("bound_method_value.jac");
    assert get_func(eng, "passed_as_argument", ctypes.c_int64)() == 169;
    assert get_func(eng, "dispatches_to_override", ctypes.c_int64)() == 21;
    assert get_func(eng, "sees_receiver_changes", ctypes.c_int64)() == 7;
    assert get_func(eng, "stored_and_called_later", ctypes.c_int64)() == 26;
}
