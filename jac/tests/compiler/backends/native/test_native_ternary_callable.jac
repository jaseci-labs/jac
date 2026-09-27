"""A conditional expression yields a callable whether a branch is a bare function.

`self.mapper = self.path_mapper if self.path_mapper is not None else keep_path`
joined an optional closure with a bare function. The two branch types did not
match, so the result widened to a boxed `any`, the function pointer was boxed
with a string tag, and the field store unboxed it as a closure: the first call
through the field jumped into the function's code as if it were a closure
record (the kernel's stub catalog crashed in abs_path on it). A bare-function
branch is now wrapped in a closure box, and lifted into the other branch's
optional type when that branch is an optional closure.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "a conditional expression over a callable and a bare function calls through" {
    (eng, _ir) = compile_native("ternary_callable.jac");
    assert get_func(eng, "ternary_default_function", ctypes.c_int64)() == 1;
    assert get_func(eng, "ternary_given_function", ctypes.c_int64)() == 1;
    assert get_func(eng, "ternary_between_functions", ctypes.c_int64)() == 3;
}
