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

import ctypes;
import os;
import subprocess;
import tempfile;
import from tests.support {
    jac_command,
    TESTS_DIR,
    compile_mir,
    compile_native,
    get_func,
    native_force_opts,
    native_str_func,
    python_run
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: tuple[str, ...] = ("2", "1", "25", "4", "rejected", "rejected", "0");

def sv_lines(fixture: str) -> list[str] {
    output = python_run(os.path.join(FIXTURES, fixture), timeout=900);
    return [
        line
        for line in output.splitlines()
        if line.strip()
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


test "the enum-constructor fixture lowers with no demotion" {
    fx = compile_mir("enum_ctor.jac", FIXTURES);
    assert not fx.demoted() , str(fx.demoted());
}


test "the call validates against every declared member" {
    (eng, _fx) = compile_native("enum_ctor.jac", FIXTURES);
    as_instance = get_func(eng, "as_instance", ctypes.c_int64, ctypes.c_int64);
    as_class = get_func(eng, "as_class", ctypes.c_int64, ctypes.c_int64);
    assert as_instance(1) == 2 , "a re-tagged member was rejected";
    assert as_class(2) == 1 , "a re-tagged member was rejected";
    guarded = native_str_func(eng, "guarded", ctypes.c_char_p, ctypes.c_int64);
    for (value, want) in [(0, b"0"), (1, b"1"), (2, b"2"), (4, b"4")] {
        assert guarded(value) == want , (
            f"{value} is missing from the validation table, so a value a "
            f"member carries was rejected"
        );
    }
    for value in [3, 7] {
        assert guarded(value) == b"rejected" , (
            f"the call lowered to the identity; {value} passed through as a member"
        );
    }
}


test "the declared-enum spelling validates the same way" {
    (eng, _fx) = compile_native("enum_ctor.jac", FIXTURES);
    level_of = get_func(eng, "level_of", ctypes.c_int64, ctypes.c_int64);
    for value in [2, 25, 40] {
        assert level_of(value) == value , (
            f"{value} is missing from the declared enum's table"
        );
    }
}


test "declared and undeclared values answer as CPython does" {
    sv = sv_lines("enum_ctor.jac");
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines("enum_ctor.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a noninteger input to an integer enum refuses by name" {
    fx = compile_mir("xmod_demote_dyn_lib.jac", FIXTURES);
    assert fx.is_demoted("from_code") , (
        f"the floating-point input lowered silently: {fx.demoted()}"
    );
    assert "Hue" in fx.reason("from_code") , fx.reason("from_code");
}

test "string enum constructors resolve values and reject missing members" {
    (eng, _fx) = compile_native("enum_ctor_string.jac", FIXTURES);
    probe = get_func(eng, "probe", ctypes.c_int64, ctypes.c_int64);
    assert [probe(i) for i in range(4)] == [1, 1, 1, -1];
}


test "a same-named local function is not read as the enum" {
    # the hook must not match the imported enum by spelling and replace this
    # module's own `Tone` function with a member lookup
    sv = sv_lines("enum_ctor_shadow_main.jac");
    assert sv == ["6", "12"] , f"server lane printed {sv}";
    na = na_lines("enum_ctor_shadow_main.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a non-integer argument refuses instead of being coerced" {
    fx = compile_mir("enum_ctor_bad_arg.jac", FIXTURES);
    assert fx.is_demoted("widen") , (
        f"a float argument was coerced into the member table: {fx.demoted()}"
    );
    assert "Level" in fx.reason("widen") , fx.reason("widen");
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
