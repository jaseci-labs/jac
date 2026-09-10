"""Two emitter crashes in container lowering, both now fixed.

An ICE is a bug even where the construct is unsupported. The contract is a
clean diagnostic or a seam, never a `TypeError` out of the IR builder. Both
faults below raised one, and both are reached from ordinary compiler code.

The first is a real fix. `dict.keys()` / `dict.values()` name their result list
`ptr` -- the flavor whose element type is canonically `i8*` -- but handed the
helper emitter the dict's *own* pointer type. Where the `ptr` helpers already
existed, the append argument did not match the list being appended to and the
builder raised; where they did not, the run would have minted a second,
incompatible layout under the same name, which is the worse of the two
outcomes because it does not raise. `rc_facts_pass._stamp_move_in` reaches this
through `list(_use_map.values())` over a `dict[int, uni.NameAtom]`.

The second was a refusal and is now a fix, in two halves that had to land
together. `[p for p in (items or [])]` -- `ownership_check_pass`'s
`_partition_sugar_reason` and three of its neighbours -- puts an empty list
literal on the right of `or` with no destination to take an element flavor
from. It picked one, differed from the operand on its left, and the two
unified at an erased `i8*`; the comprehension then could not tell which list
layout to read it as, and raised.

Supplying the flavor from the left operand was tried once and rejected,
because a sibling shape -- an optional list produced by a ternary and held in
a local -- then lowered to code that faulted at run time rather than refusing,
trading a loud compile-time crash for a silent miscompile. That fault has a
cause of its own: `_to_bool` read the length field off a container pointer
without checking it for null, so `x or []` over an absent list dereferenced
address zero. A null container is falsy now, which is what `None` is in
CPython, and both shapes answer correctly on both arms. The two tests below
pin the layout and the run-time answers together, so neither half can be
reverted alone.
"""

import ctypes;
import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, native_address, native_force_opts }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     _ENGINE: list = [];


"""JIT the fixture once; return its execution engine."""
def engine -> any {
    if _ENGINE {
        return _ENGINE[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "container_ice_guards.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the container fixture";
    _ENGINE.append(eng);
    return eng;
}


"""Call a zero-argument fixture function returning an i64."""
def call(name: str) -> int {
    addr = native_address(engine(), name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}


test "dict values of archetypes reach a list intact" {
    assert call("dict_values_count") == 2 , (
        f"expected 2 values, got {call('dict_values_count')}"
    );
    assert call("dict_values_ptr") == 7 , (
        f"reading .n back off the values list gave {call('dict_values_ptr')}, "
        "expected 7 -- the list slots do not hold usable pointers"
    );
}


test "dict keys of strings reach a list intact" {
    assert call("dict_keys_str") == 5 , (
        f"total key length {call('dict_keys_str')}, expected 5"
    );
}


test "values taken from a dict keep their identity" {
    assert call("dict_values_then_dedup") == 1 , (
        f"one object stored twice gave {call('dict_values_then_dedup')} ids, "
        "expected 1 -- the values list is handing back copies or garbage"
    );
}


test "a tuple-keyed set dedups by value" {
    assert call("tuple_keyed_set") == 2 , (
        f"expected 2 distinct tuple keys, got {call('tuple_keyed_set')}"
    );
}


test "compr over or lowers, and its absent arm is falsy rather than a fault" {
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, "compr_or_erased.jac"),
            options=CompileOptions(force_codespace='native')
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(os.path.join(FIXTURES, "compr_or_erased.jac")));
    seams = [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
    assert not seams , (
        f"the `or`-defaulted comprehension shapes all lower now, got: {seams}"
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    for fn in [
        "compr_over_or",
        "tern_local_or",
        "tern_local_compr",
        "tern_inline_or"
    ] {
        assert fn in ir.gen.native_layout.functions , f"{fn} demoted";
    }
}


test "an optional list held across a branch answers rather than dereferencing null" {
    # The shape that made the first attempt at this unsound: a ternary puts
    # `None` in a local whose lowered type is a bare container pointer, and
    # `x or []` then asked whether it was truthy. Reading the length field off
    # a null container faulted at run time -- a silent miscompile in place of
    # the old loud refusal. A null container is falsy now, so the `or` takes
    # its right arm and the answers match CPython on both arms.
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "compr_or_erased.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the or-defaulted fixture";
    for (fn, present, absent) in [
        ("tern_local_or", 7, 0),
        ("tern_local_compr", 2, 0),
        ("tern_inline_or", 7, 0)
    ] {
        addr = native_address(eng, fn);
        assert addr != 0 , f"'{fn}' is absent from the JIT engine";
        _f = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
        assert _f(1) == present , f"{fn}(True) must be {present}";
        assert _f(0) == absent , (
            f"{fn}(False) must be {absent}: the absent list is falsy, not a "
            "null dereference"
        );
    }
}
