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

# --- first-class iter() / next() (#6403 phase 2) ---
# `it = iter(x); next(it)` and `for x in it` over a stored iterator value, now
# that the native checker infers `iter(x) -> Iterator[T]` / `next(it) -> T`
# through the same __iter__/__next__ machinery the for-loop uses.
test "iter next basic" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "iter_next_basic", ctypes.c_int64);
    assert f() == 57;
}

test "iter for over stored iterator" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_iter", ctypes.c_int64);
    assert f() == 10;
}

test "iter str iter next" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "str_iter_next", ctypes.c_int64);
    assert f() == 2;
}

# next() past the end raises StopIteration (Python contract), caught here.
test "iter next exhausted raises stopiteration" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "next_exhausted", ctypes.c_int64);
    assert f() == 99;
}

# --- M1: first-class iter() over range / dict / set ---
test "iter over range" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_range_iter", ctypes.c_int64);
    assert f() == 10;
}

test "iter next over stepped range" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "next_range", ctypes.c_int64);
    assert f() == 1013;
}

test "iter over descending range" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_range_desc", ctypes.c_int64);
    assert f() == 15;
}

test "iter over dict yields keys" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_dict_iter", ctypes.c_int64);
    assert f() == 3;
}

test "iter over set" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_set_iter", ctypes.c_int64);
    assert f() == 12;
}

# --- composition: adapter over a stored iterator ---
test "iter map over stored iterator" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "map_over_stored", ctypes.c_int64);
    assert f() == 12;
}

# --- #6403: iter() of a stored iterator must retain (no double-release UAF) ---
# `iter(it)` returns the same JacIter the variable owns; the loop's owned
# reference must carry its own +1 so the source's single +1 is not released
# twice (loop end + scope exit).
test "iter for over iter of stored iterator" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "for_over_iter_of_stored", ctypes.c_int64);
    assert f() == 10;
}

test "iter assign iter of stored iterator" {
    (eng, _) = compile_native("iter_protocol.na.jac");
    f = get_func(eng, "assign_iter_of_stored", ctypes.c_int64);
    assert f() == 10;
}

# --- #6403: iter()/next() are positional-only; the keyword form is rejected ---
# The checker must not type a keyword call (`next(it=...)`) that the backend
# cannot lower — it should fail at the type level like CPython does.
test "iter next keyword arg rejected" {
    prog = JacProgram();
    prog.compile(file_path=str(os.path.join(FIXTURES, "iter_kwarg_rejected.na.jac")));
    errs = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert errs , "expected a type error for next(it=...)";
    assert any("does not match any parameter" in e for e in errs) , errs;
}

# --- #6403 M2: user-defined __iter__/__next__ bridged into the protocol ---
# A user `obj` implementing the iterator protocol drives for-loops, works with
# first-class iter()/next(), composes under map/filter/enumerate, and crosses
# function boundaries — its `__next__`'s StopIteration becomes the protocol's
# i1-0 exhaustion flag.
test "user iter self for-loop" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_self_for", ctypes.c_int64);
    assert f() == 10;
}

test "user iter borrowed var for-loop" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_self_for_var", ctypes.c_int64);
    assert f() == 3;
}

test "user iter separate iterator for-loop" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_separate_for", ctypes.c_int64);
    assert f() == 6;
}

test "user iter first-class iter next" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_iter_next", ctypes.c_int64);
    assert f() == 1011;
}

test "user iter under map adapter" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_map_compose", ctypes.c_int64);
    assert f() == 6;
}

test "user iter break mid-iteration" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_break", ctypes.c_int64);
    assert f() == 3;
}

test "user iter crosses function boundary" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_cross_fn", ctypes.c_int64);
    assert f() == 10;
}

# A non-StopIteration error from __next__ must propagate, not end the loop.
test "user iter next non-stopiteration propagates" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_next_propagates", ctypes.c_int64);
    assert f() == 42;
}

# A subclass driving __iter__/__next__ inherited from its base.
test "user iter inherited from base" {
    (eng, _) = compile_native("iter_user.na.jac");
    f = get_func(eng, "user_inherited_iter", ctypes.c_int64);
    assert f() == 6;
}
