"""`any` and `all` ask the element for its truth, not for a nonzero integer.

The `any`/`all` emitters compared the element the list's `get` helper handed
back against `ir.Constant(i64, 0)` whatever that element's type was. For a
list of int that happens to be right. For every other element type the
comparison is between a value and a constant of an unrelated type, and for a
pointer element llvmlite prints it as `icmp ne i8* %"any.elem", 0`, which is
not parseable LLVM IR: the whole module dies with

    error: integer constant must have integer type

so a single `any(list_of_str)` anywhere took out the module's IR with a
parse error rather than a diagnostic, and every root whose closure reached
it lost its artifact with no seam to name the cause. That is the ICE class:
a compiler-side defect must either lower or refuse by name, never emit IR
the backend cannot read.

Both emitters now route the element through `_to_bool`, the same truth test
the rest of the emitter uses, which knows str descriptors, floats, i1,
pointers, optionals and jacvals. `_to_bool` may split the block it is given
(optionals and containers branch), so the loop's back-edge is registered
from the block the truth test actually ends in rather than from the block it
started in. Where the truth test does not lower to an i1 the emitter returns
None, which is this file's refusal channel: the caller reports an
unsupported builtin and demotes the one callable, instead of handing the
backend an unreadable module.

The fixture covers each element family against both a true and a false
answer, because a truth test that always answers "nonzero pointer" also
compiles.
"""

import ctypes;
import os;
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR, native_address, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "any_all_elem_truthiness.jac";

glob _MEMO: list = [];

"""Compile the fixture once and return (coverage record, engine)."""
def measured -> tuple {
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    na_coverage_begin();
    ir = None;
    try {
        ir = prog.compile(file_path=path, options=native_force_opts());
    } finally {
        coverage = na_coverage_end();
    }
    errors = [str(e) for e in (prog.errors_had or [])];
    rec = coverage.get(os.path.realpath(path)) or coverage.get(path);
    out = (rec, errors, (ir.gen.native_engine if ir is not None else None), );
    _MEMO.append(out);
    return out;
}

"""Call a no-argument fixture function through the JIT."""
def answer(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"function '{name}' is not in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}


test "a list of non-integer elements does not take the module's IR with it" {
    (rec, errors, eng) = measured();
    assert not errors , (
        f"a module whose only unusual content is any()/all() over non-integer "
        f"elements must compile: {errors}"
    );
    assert rec is not None , "the fixture produced no native coverage record";
    assert rec.get("outcome") == "native" , (
        f"the fixture must lower natively, got {rec.get('outcome')}: "
        f"{rec.get('code')} {rec.get('detail')}"
    );
    assert not (rec.get("seams") or []) , (
        f"no seam is expected here: {[str(s) for s in (rec.get('seams') or [])]}"
    );
    assert eng is not None , "no JIT engine was produced for the fixture";
}

test "str elements answer with their own emptiness" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "any_str_none") == 0;
    assert answer(eng, "any_str_some") == 1;
    assert answer(eng, "all_str_yes") == 1;
    assert answer(eng, "all_str_no") == 0;
}

test "float elements answer with their own value" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "any_float_none") == 0;
    assert answer(eng, "any_float_some") == 1;
    assert answer(eng, "all_float_no") == 0;
}

test "bool elements answer with themselves" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "any_bool_none") == 0;
    assert answer(eng, "any_bool_some") == 1;
    assert answer(eng, "all_bool_no") == 0;
}

test "int elements keep the answer they always had" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "any_int_none") == 0;
    assert answer(eng, "any_int_some") == 1;
    assert answer(eng, "all_int_yes") == 1;
    assert answer(eng, "all_int_no") == 0;
}
