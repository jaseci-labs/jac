"""`auto()` members fold, so an enum read off the class lowers (#8288).

`ParameterCategory` in `types.jac` spells its three members `auto()`, and
that one detail cost the type evaluator a fifth of its file. A member value
reached the backend through `fold_const`, which sees a `FuncCall` and answers
"not a constant", so the member had no literal, the class-form layout dropped
it, and `ParameterCategory.ArgsList` lowered to nothing --
`get_type_of_ability` demoted on the read, `get_type_of_expression` demoted on
the call, and twenty-one more methods demoted on that.

`auto()` has no value of its own to fold; CPython generates one from the
members already assigned. That makes it a question about the declaration
rather than the expression, which is why the answer lives beside the enum's
layout instead of in the constant folder: the members arrive in source order
and the generated value is `max(seen) + 1`, counting from 1.

Counting from the largest rather than the last is the part worth pinning.
`High = 10; Low = 3; Next = auto()` is `11` in CPython, not `4`, and a rule
that tracked the previous member would answer the second and stay wrong
quietly, because nothing else in the file would disagree with it.

Two things still refuse, and they refuse rather than guess. A generated value
that follows a member the fold could not reach has no maximum to count from,
so it stays unknown and `all_values_known` reads false. And the name is
matched through its symbol, not its spelling: a module-local function called
`auto` is not `enum`'s, so `enum_auto_shadow.jac` keeps its seam and the
server lane answers what CPython answers.
"""

import contextlib;
import io;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR, native_force_opts }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     EXPECTED: tuple = ("1", "2", "3", "10", "3", "1112", "129");

def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
    );
    return (prog, ir, );
}


"""The seam report a build would show on stderr for a fixture."""
def seam_report(fixture: str) -> str {
    buf = io.StringIO();
    prog = JacProgram();
    with contextlib.redirect_stderr(buf) {
        prog.compile(
            file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
        );
    }
    return buf.getvalue();
}


def sv_lines(fixture: str) -> list {
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(FIXTURES, fixture)],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"server run failed: {proc.stderr[-800:]}";
    return [
        _l
        for _l in proc.stdout.split("\n")
        if _l.strip()
    ];
}


def na_lines(fixture: str) -> list {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            os.path.join(FIXTURES, fixture),
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary exited {proc.returncode}: {proc.stderr[-400:]}";
    return [
        _l
        for _l in proc.stdout.split("\n")
        if _l.strip()
    ];
}


test "an all-auto enum lowers with no seam" {
    (prog, ir) = compile_native("enum_auto.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the fixture";
    seams = seam_report("enum_auto.jac");
    assert "attribute access" not in seams , (
        f"a member read off the class still refused:\n{seams}"
    );
}


test "generated values count from the largest already assigned" {
    (prog, ir) = compile_native("enum_auto.jac");
    reg = get_layout_registry(ir, prog);
    cat = reg.get_enum_layout("Cat");
    assert cat is not None and cat.all_values_known , (
        "the all-auto enum's table is still unencodable"
    );
    cat_values = [(m.name, m.int_value) for m in cat.members];
    assert cat_values == [("Positional", 1), ("ArgsList", 2), ("KwargsDict", 3)] , f"Cat generated {cat_values}";
    mixed = reg.get_enum_layout("Mixed");
    assert mixed is not None and mixed.all_values_known , (
        "the mixed enum's table is still unencodable"
    );
    mixed_values = [(m.name, m.int_value) for m in mixed.members];
    assert mixed_values == [("High", 10), ("Low", 3), ("Next", 11), ("After", 12)] , (
        f"Mixed generated {mixed_values}; counting from the last member "
        f"rather than the largest would read 4"
    );
}


test "the declared-enum spelling generates the same way" {
    (prog, ir) = compile_native("enum_auto.jac");
    reg = get_layout_registry(ir, prog);
    step = reg.get_enum_layout("Step");
    assert step is not None , "the declared enum lost its layout";
    step_values = [(m.name, m.int_value) for m in step.members];
    assert step_values == [("First", 1), ("Second", 2), ("Third", 9)] , f"Step generated {step_values}";
}


test "generated values answer as CPython does" {
    sv = sv_lines("enum_auto.jac");
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines("enum_auto.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a module-local auto is not read as the enum's" {
    seams = seam_report("enum_auto_shadow.jac");
    assert "attribute access 'Soft'" in seams , (
        f"this module's own `auto` was counted as a generated value:\n{seams}"
    );
    (prog, ir) = compile_native("enum_auto_shadow.jac");
    reg = get_layout_registry(ir, prog);
    tone = reg.get_enum_layout("Tone");
    assert tone is not None and not tone.all_values_known , (
        "a member the fold cannot reach was reported as known"
    );
    sv = sv_lines("enum_auto_shadow.jac");
    assert sv == ["40"] , f"server lane printed {sv}";
}
