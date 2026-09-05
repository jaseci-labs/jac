"""`list.extend` reads its source through the same coercion every other method uses.

A dict's value slot is erased, so iterating `d.values()` yields a raw `i8*`
even where the declared value type is a list. `NativeListEmitter.emit_extend`
took `args[0]` and went straight to a GEP for the length header. On a raw box
that GEP walks into an `i8`, and llvmlite's type walk raises `AttributeError:
'IntType' object has no attribute 'gep'` -- which the primitive-method wrapper
catches and reports as E5092, so the shape reads as "extend is not lowered"
when in fact only the erased-source case was missing.

That is the exact shape `capability_check_pass` uses to flatten its per-owner
violation map:

    _demotable: dict[int, list[...]];
    for _unit_viols in _demotable.values() {
        _report.extend(_unit_viols);
    }

The source is now coerced to the target's list type when it does not already
point at a list header -- the same `_coerce_type` unboxing `append`, `insert`
and the spread helpers already do -- and a source that still is not a list
after that returns None, so the refusal is a refusal instead of a raised
exception. `extend_plain_list` pins the already-typed path, which never went
through the box and must not start now.
"""

import ctypes;
import os;
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
        file_path=os.path.join(FIXTURES, "list_extend_boxed.jac"),
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for the extend fixture";
    _ENGINE.append(eng);
    return eng;
}


"""A fixture function taking one bool and returning an i64."""
def flag_fn(name: str) -> any {
    addr = native_address(engine(), name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_bool)(addr);
}


test "extending from a dict's list values lands every element" {
    fn = flag_fn("count_str_lists");
    assert fn(True) == 3 , f"expected 3 elements, got {fn(True)}";
    assert fn(False) == 0 , f"the un-extended arm gave {fn(False)}, expected 0";
}


test "the elements pulled through the box are usable" {
    fn = flag_fn("extend_str_lists");
    assert fn(True) == 6 , (
        f"summing len() over the extended list gave {fn(True)}, expected 6 -- "
        "the slots do not hold usable strings"
    );
    assert fn(False) == 0 , f"the un-extended arm gave {fn(False)}, expected 0";
}


test "a list of tuples extends through the same erased slot" {
    fn = flag_fn("count_tuple_lists");
    assert fn(True) == 3 , f"expected 3 tuples, got {fn(True)}";
    assert fn(False) == 0 , f"the un-extended arm gave {fn(False)}, expected 0";
}


test "an already-typed source still extends without the coercion" {
    fn = flag_fn("extend_plain_list");
    assert fn(True) == 16 , f"expected 1+4+5+6, got {fn(True)}";
    assert fn(False) == 1 , f"the un-extended arm gave {fn(False)}, expected 1";
}
