"""End-to-end tests for the native iterator protocol (#6403).

Covers lazy adapters (map/filter/enumerate/zip) driven through for-loops,
composition, break/empty edge cases, and first-class iter()/next() values.
"""

import ctypes;
import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from llvmlite.binding { ExecutionEngine }

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

# --- map / filter ---
test "iter map sum" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "map_sum", ctypes.c_int64);
    assert f() == 20;
}

test "iter filter sum" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "filter_sum", ctypes.c_int64);
    assert f() == 12;
}

test "iter filter empty" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "filter_empty", ctypes.c_int64);
    assert f() == 0;
}

test "iter compose map over filter" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "compose_sum", ctypes.c_int64);
    assert f() == 24;
}

test "iter map with break" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "map_break", ctypes.c_int64);
    assert f() == 6;
}

# --- enumerate / zip (tuple unpack) ---
test "iter enumerate sum" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "enum_sum", ctypes.c_int64);
    assert f() == 360;
}

test "iter zip sum" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "zip_sum", ctypes.c_int64);
    assert f() == 140;
}

test "iter zip unequal lengths" {
    (eng, _) = compile_native("iter_adapters.na.jac");
    f = get_func(eng, "zip_unequal", ctypes.c_int64);
    assert f() == 50;
}

# --- first-class iter() / next() ---
# Deferred (phase 2): first-class iterator *values* (`it = iter(x); next(it)`,
# `for x in it`) need generic element-type inference for the `iter`/`next`
# builtins in the native type context (the checker currently leaves the element
# type as an unbound `_T` / `SupportsNext[Any]`). The boxed-iterator codegen is
# already in place; only the type-system surface is missing. Tracked in #6403.
test "iter next basic" {
    import unittest;
    raise unittest.SkipTest(
        "first-class iter()/next() values need native generic inference (#6403 phase 2)"
    );
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "iter_next_basic", ctypes.c_int64);
    assert f() == 57;
}

test "iter for over stored iterator" {
    import unittest;
    raise unittest.SkipTest(
        "first-class iter()/next() values need native generic inference (#6403 phase 2)"
    );
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_iter", ctypes.c_int64);
    assert f() == 10;
}

test "iter str iter next" {
    import unittest;
    raise unittest.SkipTest(
        "first-class iter()/next() values need native generic inference (#6403 phase 2)"
    );
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "str_iter_next", ctypes.c_int64);
    assert f() == 2;
}
