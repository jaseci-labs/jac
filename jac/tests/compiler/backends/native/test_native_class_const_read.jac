"""A class-level attribute read through `self` answers per class (#8256).

`self.CATEGORY` -- a `ClassVar` the abstract base declares and every subclass
redefines -- reached `_codegen_field_access`, missed the instance layout, and
came back `None`. #8253 narrowed the field-access refusal to the inherited
case so this would not turn into unwaived demotions, which left the read
silent: `_codegen_bound_args` substitutes `_default_arg_fallback` for an
argument that did not lower, so `_init_stub(self, sym_type=self.SYMBOL_TYPE)`
passed enum ordinal 0 and every `Literal` subclass claimed the base's symbol
type.

The values were never missing. A class-level declaration is a compile-time
constant: each declaring class answers its own value through the receiver,
and where the declaring base carries no value at all the read raises
`AttributeError` rather than handing back a zero.

The subprocess pair is the contract: the server pathway and a native binary
must print the same lines, so the *values* are pinned and not merely that
something lowered. The other half -- `TypeBase.category.__get__` leaving its
waiver when this landed -- was pinned by `test_type_system_seal_baseline`,
deleted with the native seal (#8735).

The last case pins the follow-up #8253 named. A flat imported ancestor with
no vtable slot puts its first field at slot 0, and a subclass kept a vtable
slot there only because it was an `isinstance` target, so its layout could
not hold the inherited name and a constructor keyword naming it was dropped.
A build whose allocations carry a header answers `isinstance` from the class
name stamped there, so the slot is dropped and the subclass adopts its
ancestor's slots verbatim.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR, by_source_name, jac_command, native_force_opts }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: tuple[str, ...] = (
         "0",
         "1",
         "2",
         "node",
         "leaf",
         "branch",
         "12",
         "5",
         "3",
         "4",
         "0.0",
         "1.5",
         "True",
         "no SIDES"
     );

"""Inspect emitted IR before optimization; runtime parity uses the built binary."""
def compile_native(fixture: str) -> tuple[any, ...] {
    prog = JacProgram();
    options = native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=options);
    return (prog, ir, );
}


def sv_lines(fixture: str) -> list[str] {
    proc = subprocess.run(
        jac_command("run", os.path.join(FIXTURES, fixture)),
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


test "the class-constant fixture lowers with no seam" {
    (prog, ir) = compile_native("class_const_read.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the fixture";
}


test "the class constants read the same on both lanes" {
    sv = sv_lines("class_const_read.jac");
    assert sv == list(EXPECTED) , f"server lane printed {sv}";
    na = na_lines("class_const_read.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a consumer links the declaring module's constants rather than redefining them" {
    (prog, ir) = compile_native("class_const_xmod_main.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    sv = sv_lines("class_const_xmod_main.jac");
    assert sv == ["6", "12", "3", "double"] , f"server lane printed {sv}";
    na = na_lines("class_const_xmod_main.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a subclass of a flat imported ancestor adopts its field slot" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "xmod_isinstance_flat_main.jac"),
        options=native_force_opts()
    );
    reg = get_layout_registry(ir, prog);
    kid = by_source_name(reg.layouts).get("MainKid");
    assert kid is not None , "no layout for MainKid";
    point = by_source_name(reg.layouts).get("Point");
    assert point is not None , "no layout for Point";
    assert dict(kid.field_index).get("x") == dict(point.field_index).get("x") , (
        f"MainKid must read 'x' where Point put it: kid {dict(kid.field_index)}, "
        f"point {dict(point.field_index)}"
    );
    assert not kid.has_vtable , (
        "MainKid is only an isinstance target; the allocation header answers "
        "that, so it must not carry a vtable slot its flat ancestor lacks"
    );
}
