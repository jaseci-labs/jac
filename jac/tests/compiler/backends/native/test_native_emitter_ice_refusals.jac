"""Previously crashing argument shapes either execute or report a checked refusal."""

import os;
import ctypes;
import from tests.support { native_str_func }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "emitter_ice_refusals.jac";

glob _MEMO: list = [];

"""Compile the fixture once and return (coverage record, program, ir)."""
def measured -> tuple {
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
    out = (seams, prog, ir, );
    _MEMO.append(out);
    return out;
}

"""The one seam owned by `name`, or the empty string."""
def seam_for(seams: list, name: str) -> str {
    owned = [
        s
        for s in seams
        if str(s).startswith(f"{name}: ")
    ];
    return owned[0] if len(owned) == 1 else "";
}


test "tuple prefixes lower and match the correct strings" {
    (seams, prog, ir) = measured();
    assert not seam_for(seams, "tuple_startswith") , str(seams);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    check = native_str_func(
        ir.gen.native_engine, "tuple_startswith", ctypes.c_int64, ctypes.c_char_p
    );
    assert check(b"'quoted") == 1;
    assert check(b'"quoted') == 1;
    assert check(b"plain") == 0;
    assert check(b"") == 0;
}


test "a mismatched call argument is the checker's refusal, not the emitter's" {
    # With type checking on the critical path a plainly-typed mismatch never
    # reaches codegen: the checker names the parameter at check time, which
    # is this pin now. The boxed variant below also checks emitter diagnostics.
    import tempfile;
    src = (
        "obj Holder { has n: int = 0; }\n"
        + "def takes_holder(h: Holder) -> int { return h.n; }\n"
        + "def arg_shape_mismatch(s: str) -> int { return takes_holder(s); }\n"
    );
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "arg_shape_probe.jac");
        with open(path, "w") as f {
            f.write(src);
        }
        prog = JacProgram();
        prog.compile(file_path=path, options=CompileOptions(force_codespace='native'));
        hits = [
            str(e)
            for e in prog.errors_had
            if e.code is not None and e.code.code == "E1053" and "'h'" in str(e)
        ];
        assert hits , (
            "the direct mismatch must be refused at check time naming the "
            f"parameter, got: {[str(e) for e in prog.errors_had]}"
        );
    }
    # The boxed variant in the fixture reaches the emitter and must not
    # raise out of the builder.
    (seams, _prog, _ir) = measured();
    assert "emitter error in" not in " ".join(seams) , (
        f"an emitter crash leaked into the seams: {seams}"
    );
}


test "the refusals are granular: their neighbours still lower" {
    (_seams, _prog, ir) = measured();
    assert ir.gen.native_layout is not None , "whole-module native compile aborted";
    for fn in ["plain_startswith", "takes_holder"] {
        assert fn in ir.gen.native_layout.functions , (
            f"{fn} lowers on its own and must not be taxed by its neighbour's "
            "refusal"
        );
    }
}
