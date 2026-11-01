"""Congruence pins for runtime enum `.value`/`.name` in string contexts.

The constant-member attribute paths wrap their table lookups into string
descriptors; the runtime path routes through the per-enum ordinal arrays
(#7985). These cases JIT-compile `fixtures/enum_attr_runtime.jac` natively
and assert that a runtime enum value's `.value`/`.name` feed `len()` and
string concatenation correctly for both enum flavours, so a raw pointer
leaking where a string is consumed shows up as a red row rather than a
sealed-artifact crash.
"""

import ctypes;
import from tests.support { compile_native as compile_fixture, native_address }
import from jaclang.compiler.backends.native.llvm.jit { ExecutionEngine }

glob _ENG: list[any] = [];

def compile_native -> ExecutionEngine {
    if _ENG {
        return _ENG[0];
    }
    (eng, _) = compile_fixture("enum_attr_runtime.jac");
    _ENG.append(eng);
    return eng;
}

def call_i64(name: str, arg: int) -> int {
    eng = compile_native();
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr)(arg);
}

test "runtime string-enum .value feeds len()" {
    assert call_i64("color_value_len", 0) == 3;
    assert call_i64("color_value_len", 1) == 5;
}

test "runtime string-enum .name feeds concatenation" {
    assert call_i64("color_name_concat", 0) == 4;
    assert call_i64("color_name_concat", 1) == 6;
}

test "runtime int-enum .name feeds len()" {
    assert call_i64("prio_name_len", 0) == 3;
    assert call_i64("prio_name_len", 1) == 4;
}

test "runtime int-enum .value is the declared value" {
    assert call_i64("prio_value_of", 0) == 1;
    assert call_i64("prio_value_of", 1) == 2;
}
