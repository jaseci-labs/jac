"""An emitter crash is a bug even where the construct is unsupported (jac#8201).

Two faults reached the IR builder with operands it could not take and raised
there. The granular-demotion layer caught the exception and reported "native
emitter error in <callable>", which is honest about the outcome and silent
about the cause: nothing in the coverage said which operand was wrong, so the
seam could not be classified or acted on.

Neither construct is supported yet, and this test does not make them supported.
It pins the other half of the contract: the refusal names the operand, the
demotion is the one callable's, and the module still lowers. If either shape
ever does lower, this test is the one to flip -- an assertion that a named
refusal is present fails loudly when the refusal stops firing, which is the
behaviour a stale waiver should have.
"""

import os;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "native", "fixtures"
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
            file_path=path,
            options=CompileOptions(
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                no_ir_cache=True
            )
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


test "a tuple prefix refuses by name rather than crashing the emitter" {
    (seams, prog, _ir) = measured();
    owned = seam_for(seams, "tuple_startswith");
    assert owned , f"expected exactly one seam for tuple_startswith, got: {seams}";
    assert "emitter error in" not in owned , (
        f"the tuple prefix must refuse, not raise out of the builder: {owned}"
    );
    assert "str.startswith" in owned , (
        f"the refusal must name the primitive method it could not emit: {owned}"
    );
    assert not prog.errors_had , (
        "an un-emittable builtin method is one callable's seam, not a module "
        f"failure: {[str(e) for e in prog.errors_had]}"
    );
}


test "a mismatched call argument refuses by callee and position" {
    (seams, _prog, _ir) = measured();
    owned = seam_for(seams, "arg_shape_mismatch");
    assert owned , f"expected exactly one seam for arg_shape_mismatch, got: {seams}";
    assert "emitter error in" not in owned , (
        f"the argument mismatch must refuse, not raise out of the builder: {owned}"
    );
    assert "takes_holder parameter 1" in owned , (
        f"the refusal must name the callee and which parameter: {owned}"
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
