"""Unit tests for `RcFactsPass`: which `b = a` move sites it proves safe.

The move-lowerability proof is a core analysis on the shared dataflow
framework; the native codegen schedule consumes the stamped
`Assignment.na_move_lowerable` facts. These fixtures are plain `.jac` files whose
hazard sources are plain RC locals (the always-on ownership checker tracks `own`
bindings, so a real `own` UAF no longer compiles), and we drive `RcFactsPass`
directly over the CFG-built IR
so the `na_move_lowerable` marks come purely from the core liveness proof. Each
fixture function has a single `bN = a` candidate; we assert the mark per candidate
by its target name.

This locks the conservative rule set: only a LOCAL source whose every use is an
alias-value into a plain local, and which is dead-out at the move site, is proven.
Every UAF channel (own-param, escape via call/field/borrow/closure/concurrent,
loop back-edge re-read) is asserted NOT proven.
"""

import os;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
import from jaclang.compiler.driver.pass_driver { run_pass }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "passes", "fixtures");

"""Map every single-target `Name = ...` assignment to its move-lowerable mark."""
def move_marks(fixture: str) -> dict[str, bool] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    # Native codegen (which schedules this pass) is gated off for plain `.jac`
    # modules, so run the proof directly over the CFG-built IR to populate marks.
    run_pass(RcFactsPass, ir, prog);
    out: dict[str, bool] = {};
    for nd in ir.get_all_sub_nodes(uni.Assignment) {
        if len(nd.target) == 1 {
            tgt = nd.target[0];
            if isinstance(tgt, uni.Name) {
                out[tgt.value] = nd.na_move_lowerable;
            }
        }
    }
    return out;
}

test "the proof marks safe local last-use moves" {
    marks = move_marks("rc_facts_cases.jac");
    assert marks["b1"] , "straight-line last-use move must be proven safe";
    assert marks["b9"] , "loop move with per-iteration redefinition must be proven safe";
}

test "the proof refuses an own-param source (own-param UAF channel)" {
    marks = move_marks("rc_facts_cases.jac");
    assert not marks["b2"] , "a param source is not LOCAL and must never be move-lowered";
}

test "the proof refuses escaping sources (call-arg, field, closure, concurrent, borrow)" {
    marks = move_marks("rc_facts_cases.jac");
    assert not marks["b3"] , "a call-arg use must disqualify the source";
    assert not marks["b4"] , "a field store must disqualify the source";
    assert not marks["b5"] , "a closure capture must disqualify the source";
    assert not marks["b6"] , "a concurrent capture must disqualify the source";
    assert not marks["b7"] , "a borrow of the source must disqualify it";
}

test "the proof refuses a loop-carried source re-read via the back-edge" {
    marks = move_marks("rc_facts_cases.jac");
    assert not marks["b8"] , "a source live across the loop back-edge must not be move-lowered";
}

test "last-use release includes later reads through a shadowed parameter name" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(
            TESTS_DIR,
            "compiler",
            "backends",
            "native",
            "fixtures",
            "rc_container_temporaries.jac"
        )
    );
    assert not prog.errors_had , [str(error) for error in prog.errors_had];
    run_pass(RcFactsPass, ir, prog);
    checked = False;
    for ability in ir.get_all_sub_nodes(uni.Ability) {
        if ability.name_ref is not None
            and ability.name_ref.sym_name == "retyped_parameter" {
            for loop in ability.get_all_sub_nodes(uni.InForStmt) {
                assert "item" not in ir.rc_last_use.get(id(loop), []);
                checked = True;
            }
        }
    }
    assert checked;
}
