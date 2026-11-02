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

String-valued enums look up the declared value and return its ordinal.
Members whose values cannot be folded still have no table to validate against,
and noninteger inputs to integer enums remain refused under E5092.

The subprocess pair is the contract: the server pathway and a native binary
print the same lines, and CPython's own answers for the same six calls are
`2 1 25 4 rejected rejected 0`.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, TESTS_DIR, native_force_opts, python_run }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: tuple[str, ...] = ("2", "1", "25", "4", "rejected", "rejected", "0");

def compile_native(fixture: str) -> tuple[any, ...] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
    );
    return (prog, ir, );
}


def sv_lines(fixture: str) -> list[str] {
    output = python_run(os.path.join(FIXTURES, fixture), timeout=900);
    return [
        line
        for line in output.splitlines()
        if line.strip()
    ];
}


"""The E5092 refusals a forced-native compile of a fixture reports, each with
the line it points at."""
def refusals(fixture: str) -> list[tuple[str, int]] {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, fixture), options=native_force_opts()
    );
    return [
        (str(e), e.loc.first_line)
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5092"
    ];
}


def na_lines(fixture: str) -> list[str] {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build", "--native", os.path.join(FIXTURES, fixture), "-o", out_bin
        ),
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


test "declared and undeclared values answer as CPython does" {
    sv = sv_lines("enum_ctor.jac");
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines("enum_ctor.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a noninteger input to an integer enum refuses by name" {
    found = refusals("xmod_demote_dyn_lib.jac");
    hits = [
        line
        for (text, line) in found
        if "enum constructor 'Hue'" in text
    ];
    assert hits , f"the floating-point input lowered silently: {found}";
    assert hits == [14] , (
        f"the refusal must point at the call inside from_code: {found}"
    );
}

test "string enum constructors resolve values and reject missing members" {
    import ctypes;
    import from tests.support { get_func }
    (prog, ir) = compile_native("enum_ctor_string.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    probe = get_func(ir.gen.native_engine, "probe", ctypes.c_int64, ctypes.c_int64);
    assert [probe(i) for i in range(4)] == [1, 1, 1, -1];
}


test "a same-named local function is not read as the enum" {
    (prog, ir) = compile_native("enum_ctor_shadow_main.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    sv = sv_lines("enum_ctor_shadow_main.jac");
    assert sv == ["6", "12"] , f"server lane printed {sv}";
    na = na_lines("enum_ctor_shadow_main.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a non-integer argument refuses instead of being coerced" {
    found = refusals("enum_ctor_bad_arg.jac");
    assert any("enum constructor 'Level'" in text for (text, _) in found) , (
        f"a float argument was coerced into the member table: {found}"
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
