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
constant, so each declaring class gets its own global and the read picks
between them on the receiver's vtable, exactly as `_emit_dispatched_field_ptr`
picks between disagreeing field offsets. Where the whole hierarchy agrees the
read is a plain load of the one global, and where the declaring base carries
no value at all the fallback arm raises `AttributeError` rather than handing
back a zero.

The subprocess pair is the contract: the server pathway and a native binary
must print the same lines, so the *values* are pinned and not merely that
something lowered. The other half -- `TypeBase.category.__get__` leaving its
waiver when this landed -- was pinned by `test_type_system_seal_baseline`,
deleted with the native seal (#8735).

The last case is the one that stays broken on purpose. A flat imported
ancestor with no vtable slot puts its first field at slot 0 while a subclass
needs that slot for one, so the subclass's layout cannot hold the inherited
name and a constructor keyword naming it is dropped. #8253 named the honest
fix -- stop giving such a subclass a vtable slot it does not need -- and left
it to its own change; the test pins the state so it cannot drift unnoticed.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR, names_global, native_force_opts, unit_symbol }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.layout_pass { get_layout_registry }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     EXPECTED: tuple = (
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
         "True"
     );

"""Compile a fixture natively and hand back the program and the module."""
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


test "the class-constant fixture lowers with no seam" {
    (prog, ir) = compile_native("class_const_read.jac");
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    assert ir is not None and ir.gen.llvm_ir , "no native IR for the fixture";
}


test "each declaring class gets its own constant" {
    (_prog, ir) = compile_native("class_const_read.jac");
    text = str(ir.gen.llvm_ir);
    for name in ("Node.CATEGORY", "Leaf.CATEGORY", "Branch.CATEGORY") {
        assert names_global(text, name) , (
            f"{name} was folded away instead of getting its own storage"
        );
    }
}


test "a redefined constant is picked on the receiver's vtable" {
    (_prog, ir) = compile_native("class_const_read.jac");
    text = str(ir.gen.llvm_ir);
    assert "cc.CATEGORY.Leaf" in text and "cc.CATEGORY.Branch" in text , (
        "the per-class read did not dispatch; a single load here would give "
        "every subclass the base's value"
    );
}


test "a constant no subclass redefines stays a plain load" {
    (_prog, ir) = compile_native("class_const_read.jac");
    text = str(ir.gen.llvm_ir);
    assert "cconst.WIDTH" in text , "the uniform read lost its direct load";
    assert "cc.WIDTH." not in text , (
        "a constant with no disagreeing subclass paid for a dispatch chain"
    );
}


test "the annotation decides the constant's shape, not the literal" {
    (_prog, ir) = compile_native("class_const_read.jac");
    text = str(ir.gen.llvm_ir);
    assert f'@"{unit_symbol(ir, "Metered.RATE")}" = global double' in text , (
        "`RATE: ClassVar[float] = 0` took its shape from the integer literal, "
        "so every read of it answers with an integer and the subclass's "
        "double-valued global cannot be dispatched against it"
    );
    assert f'@"{unit_symbol(ir, "Fast.RATE")}" = global double' in text , "the override lost its shape";
    assert "cc.RATE.Fast" in text , (
        "the float constant did not dispatch, which is what a shape "
        "disagreement between base and subclass looks like"
    );
}


test "a declaration with no value raises instead of defaulting" {
    (_prog, ir) = compile_native("class_const_read.jac");
    text = str(ir.gen.llvm_ir);
    assert "cc.SIDES.Tri" in text and "cc.SIDES.Quad" in text , (
        "the abstract base's read did not dispatch to its subclasses"
    );
    assert "raise.AttributeError" in text , (
        "the fallback arm handed back a zero for a class that declares no "
        "value, which is the silent default this change removes"
    );
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
    text = str(ir.gen.llvm_ir);
    for line in text.split("\n") {
        if line.startswith(f'@"{unit_symbol(ir, "Unit.SCALE")}"') or line.startswith(f'@"{unit_symbol(ir, "Double.SCALE")}"') {
            assert "external global" in line , (
                f"the consumer defined an imported class's constant, which "
                f"gives the link two definitions of one symbol: {line.strip()}"
            );
        }
    }
    sv = sv_lines("class_const_xmod_main.jac");
    assert sv == ["6", "12", "3", "double"] , f"server lane printed {sv}";
    na = na_lines("class_const_xmod_main.jac");
    assert na == sv , f"native {na} != server {sv}";
}


test "a flat imported ancestor still holds no slot for its field" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "xmod_isinstance_flat_main.jac"),
        options=native_force_opts()
    );
    reg = get_layout_registry(ir, prog);
    kid = reg.get_layout("MainKid");
    assert kid is not None , "no layout for MainKid";
    assert "x" not in dict(kid.field_index) , (
        "MainKid adopted its flat ancestor's slot assignment; if that is "
        "intended, the constructor-keyword drop below is now reachable and "
        "this pin should become an equality check instead"
    );
    assert kid.has_vtable , (
        "MainKid lost the vtable slot that makes the ancestor's slot 0 "
        "unusable; #8253's follow-up landed and this pin is stale"
    );
}
