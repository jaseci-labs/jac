"""A class-level attribute read through `self` answers per class (#8256).

`self.CATEGORY` -- a `ClassVar` the abstract base declares and every subclass
redefines -- missed the instance layout and came back `None`, and an argument
that did not lower was silently replaced by a default, so
`_init_stub(self, sym_type=self.SYMBOL_TYPE)` passed enum ordinal 0 and every
`Literal` subclass claimed the base's symbol type.

The values were never missing. A class-level declaration is a compile-time
constant, so each declaring class gets its own global and the read picks
between them on the receiver's vtable, exactly as a field read picks between
disagreeing field offsets. Where the whole hierarchy agrees the
read is a plain load of the one global, and where the declaring base carries
no value at all the fallback arm raises `AttributeError` rather than handing
back a zero.

The subprocess pair is the contract: the server pathway and a native binary
must print the same lines, so the *values* are pinned and not merely that
something lowered.

The last case pins the follow-up #8253 named. A flat imported ancestor with
no vtable slot puts its first field at slot 0, and a subclass kept a vtable
slot there only because it was an `isinstance` target, so its layout could
not hold the inherited name and a constructor keyword naming it was dropped.
A build whose allocations carry a header answers `isinstance` from the class
name stamped there, so the slot is dropped and the subclass adopts its
ancestor's slots verbatim.
"""

import ctypes;
import os;
import re;
import subprocess;
import tempfile;
import from tests.support {
    TESTS_DIR,
    compile_mir,
    compile_native,
    compile_native_ir,
    get_func,
    jac_command,
    names_global,
    source_spelled,
    unit_symbol
}

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
         "True"
     );

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


test "the class-constant fixture lowers with nothing demoted" {
    demoted = compile_mir("class_const_read.jac").demoted();
    assert not demoted , f"the class-constant fixture demoted: {demoted}";
}


test "each declaring class gets its own constant" {
    text = source_spelled(compile_native_ir("class_const_read.jac").llvm_ir());
    for name in ("Node.CATEGORY", "Leaf.CATEGORY", "Branch.CATEGORY") {
        assert names_global(text, name) , (
            f"{name} was folded away instead of getting its own storage"
        );
    }
}


test "the annotation decides the constant's shape, not the literal" {
    fx = compile_native_ir("class_const_read.jac");
    text = source_spelled(fx.llvm_ir());
    for name in ("Metered.RATE", "Fast.RATE") {
        symbol = re.escape(source_spelled(unit_symbol(fx, name)));
        assert re.search(rf'@"?{symbol}"? = (?:\w+ )*global double', text) , (
            f"`{name}: ClassVar[float] = 0` took its shape from the integer "
            "literal, so every read of it answers with an integer and the "
            "subclass's double-valued global cannot be dispatched against it"
        );
    }
}


test "a declaration with no value raises instead of defaulting" {
    text = compile_mir("class_const_read.jac").mir();
    assert "raise @AttributeError" in text , (
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
    fx = compile_native_ir("class_const_xmod_main.jac");
    text = source_spelled(fx.llvm_ir());
    for line in text.split("\n") {
        if line.startswith(f'@"{source_spelled(unit_symbol(fx, "Unit.SCALE"))}"')
            or line.startswith(
                f'@"{source_spelled(unit_symbol(fx, "Double.SCALE"))}"'
            ) {
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


test "a subclass of a flat imported ancestor adopts its field slot" {
    (eng, _) = compile_native("xmod_isinstance_flat_main.jac");
    kid = get_func(eng, "chk_kid", ctypes.c_int64, ctypes.c_int64);
    assert [kid(k) for k in range(4)] == [1, 1, 1, 0] , (
        "MainKid is only an isinstance target; the allocation header answers "
        "that, so a MainKid built with its ancestor's keyword must still be a "
        "Point and a plain Point must not be read through a vtable slot"
    );
    leaf = get_func(eng, "chk_kid_leaf", ctypes.c_int64, ctypes.c_int64);
    assert [leaf(0), leaf(1)] == [1, 0] , "MainKid is told apart from Point";
}
