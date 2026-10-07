"""A method call on an `any` receiver refuses loudly instead of vanishing."""

import os;
import ctypes;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT, get_func }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "any_receiver_method_refusal.jac";

glob _MEMO: list[any] = [];

"""Compile the fixture once and return (seams, ir)."""
def measured -> tuple[any, ...] {
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=path, options=CompileOptions(force_codespace='native')
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(path));
    seams = [str(s) for s in ((rec.get("seams") or []) if rec is not None else [])];
    out = (seams, ir, );
    _MEMO.append(out);
    return out;
}

"""The one seam owned by `name`, or the empty string."""
def seam_for(seams: list[any], name: str) -> str {
    owned = [
        s
        for s in seams
        if str(s).startswith(f"{name}: ")
    ];
    return owned[0] if len(owned) == 1 else "";
}


test "mutating and reading methods on an any receiver demote their callable" {
    # These calls used to lower to nothing at all: the call was dropped from
    # the IR and the function returned as if it had run.
    (seams, _ir) = measured();
    for fn in ["any_field_append", "any_field_bytearray_append", "any_param_count"] {
        seam = seam_for(seams, fn);
        assert "[E5092]" in seam and "on an `any` receiver" in seam , (
            f"{fn} must refuse its `any` receiver method call, got: {seams}"
        );
    }
}


test "the concretely typed twins still lower and run" {
    (seams, ir) = measured();
    assert not seam_for(seams, "typed_field_append") , str(seams);
    run = get_func(ir.gen.native_engine, "typed_field_append", ctypes.c_int64);
    assert run() == 21;
}


test "a File parameter's methods lower without a preceding open" {
    # The File helpers used to be emitted only by `open()`, so `fp.read()` on
    # a parameter in a unit that never opens a file found no method and was
    # dropped the same silent way.
    (seams, _ir) = measured();
    assert not seam_for(seams, "file_param_read") , str(seams);
}
