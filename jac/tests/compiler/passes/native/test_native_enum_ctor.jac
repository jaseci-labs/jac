"""An enum invoked as a constructor validates against its members (#8266).

`TypeFlags(...)` in `types.jac` re-tags a cloned type's flags: mask one bit
off, OR another on, hand the result back through the constructor. `TypeFlags`
is an `IntEnum`, not an `IntFlag`, so CPython accepts only a value some member
carries and raises `ValueError` for anything else -- `Instantiable|Instance`
included. Lowering the call to the identity would have dropped that check, so
the backend refused the whole shape and two `types.jac` methods sat behind a
waiver.

For an int-valued enum the member *is* the value: the layout already carries
the declared table, so the emitter tests the argument against it and calls the
same raise primitive `int()` uses for a bad literal. The call then returns the
value it validated, which is the member's runtime form.

What stays refused is named rather than generic. A string-valued enum's
runtime form is the member's *ordinal*, so the lookup is not the identity, and
a member whose value no fold reaches -- `ParameterCategory`'s `auto()` -- has
no table to validate against at all. Both refuse under E5092 with a help text
that says which of the two it is; `EnumLayout.all_values_known` is what makes
the second answerable rather than guessed, because the layout builder already
skipped the members it could not fold.

The subprocess pair is the contract: the server pathway and a native binary
print the same lines, and CPython's own answers for the same six calls are
`2 1 25 4 rejected rejected 0`.
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
     EXPECTED: tuple = ("2", "1", "25", "4", "rejected", "rejected", "0");

def compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
    );
    return (prog, ir, );
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


test "the enum-constructor fixture lowers with no seam" {
    (prog, ir) = compile_native("enum_ctor.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the fixture";
}


test "the call validates against every declared member" {
    (_prog, ir) = compile_native("enum_ctor.jac");
    text = str(ir.gen.llvm_ir);
    for member in ("Null", "Instantiable", "Instance", "Ambiguous") {
        assert f"ec.Flags.{member}" in text , (
            f"'{member}' is missing from the validation table, so a value it "
            f"carries would be rejected"
        );
    }
    assert "raise.ValueError" in text , (
        "the call lowered to the identity; an undeclared value would pass "
        "through as a member"
    );
}


test "the declared-enum spelling validates the same way" {
    (_prog, ir) = compile_native("enum_ctor.jac");
    text = str(ir.gen.llvm_ir);
    for member in ("LOW", "MID", "HIGH") {
        assert f"ec.Level.{member}" in text , (
            f"'{member}' is missing from the declared enum's table"
        );
    }
}


test "declared and undeclared values answer as CPython does" {
    sv = sv_lines("enum_ctor.jac");
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines("enum_ctor.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a string-valued enum constructor refuses by name" {
    seams = seam_report("xmod_demote_dyn_lib.jac");
    assert "enum constructor 'Hue'" in seams , (
        f"the string-valued spelling lowered silently:\n{seams}"
    );
    assert "from_code" in seams , (
        f"the refusal did not demote the callable that owns it:\n{seams}"
    );
}


test "a same-named local function is not read as the enum" {
    (prog, ir) = compile_native("enum_ctor_shadow_main.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    text = str(ir.gen.llvm_ir);
    assert "ec.Tone.SOFT" not in text , (
        "the hook matched the imported enum by spelling, so this module's own "
        "`Tone` function was replaced by a member lookup"
    );
    sv = sv_lines("enum_ctor_shadow_main.jac");
    assert sv == ["6", "12"] , f"server lane printed {sv}";
    na = na_lines("enum_ctor_shadow_main.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a non-integer argument refuses instead of being coerced" {
    seams = seam_report("enum_ctor_bad_arg.jac");
    assert "enum constructor 'Level'" in seams , (
        f"a float argument was coerced into the member table:\n{seams}"
    );
}


test "a member the fold cannot reach leaves the table unknown" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "enum_ctor.jac"), options=native_force_opts()
    );
    reg = get_layout_registry(ir, prog);
    flags = reg.get_enum_layout("Flags");
    assert flags is not None and flags.all_values_known , (
        "the bit-shifted members did not fold, so the validation table would "
        "have been declared unencodable"
    );
    assert len(flags.members) == 4 , f"Flags lost members: {len(flags.members)}";
}
