"""A unit keeps its own functions named after an imported C extern native.

A unit's native layout is the export table its importers bind against: a
function missing from it counts as demoted, and a caller emitted against it
refuses the call (E5092) and demotes with it.
The layout builder skipped every `func_symtab` name found in
`_clib_symbol_lib`, which it meant as "this entry is a C extern". But lowering
an importer's clib bindings records their names in the importer's table too,
so a unit that defines its own `sqrt` while importing a module that binds C's
`sqrt` left its own `sqrt` out of the layout.

The bundled `math` is that unit: it defines `sqrt`, `sin`, `cos` and most of
its other functions over `_math_native`, which binds libm under the same
names. An importer only reads the layout of a unit compiled in the same
process; when the unit comes from the IR cache there is no layout, and the
call binds normally. So a build that compiled `math` itself (a fresh compiler
cache, or any compiler change) demoted every native caller of `math.sqrt`,
and whole modules fell back to the server codespace behind it, while a build
that found `math` in the IR cache lowered cleanly.
"""

import os;
import re;
import shutil;
import subprocess;
import tempfile;
import from tests.support { compile_native_ir, jac_command, TESTS_DIR }
import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     LAYOUT_FIXTURES: list[str] = [
         "layout_clib_name_main.jac",
         "layout_clib_name_mid.jac",
         "layout_clib_name_lib.jac",
         "layout_clib_name_ffi.jac"
     ];

"""The public free functions (no class, no leading underscore) a compiled
unit demoted, by source name."""
def demoted_public_functions(fx: any) -> list[str] {
    prefix = fx.iface().prefix + ".";
    names: list[str] = [];
    for symbol in fx.demoted() {
        if not symbol.startswith(prefix) {
            continue;
        }
        name = symbol[len(prefix):];
        if "." not in name and not name.startswith("_") {
            names.append(name);
        }
    }
    return sorted(names);
}

"""Copy the fixtures into a fresh directory and `jac run` the entry there."""
def run_in_fresh_dir(runs: int) -> list[subprocess.CompletedProcess] {
    work = os.path.realpath(tempfile.mkdtemp(prefix="jac_layout_clib_names_"));
    try {
        for name in LAYOUT_FIXTURES {
            shutil.copy(os.path.join(FIXTURES, name), os.path.join(work, name));
        }
        return [
            subprocess.run(
                jac_command("run", os.path.join(work, LAYOUT_FIXTURES[0])),
                cwd=work,
                capture_output=True,
                text=True,
                timeout=900
            ) for _ in range(runs)
        ];
    } finally {
        shutil.rmtree(work, ignore_errors=True);
    }
}

test "a unit's own sqrt stays in its layout beside an imported C sqrt" {
    fx = compile_native_ir("layout_clib_name_lib.jac");
    assert re.search(r'declare [^\n]*@"?sqrt"?\(double', fx.llvm_ir()) , (
        "the fixture no longer links C's sqrt beside its own"
    );
    assert not fx.is_demoted("sqrt") , f"the library's own sqrt demoted: {fx.reason('sqrt')}";
    assert "sqrt" in fx.iface().exports , (
        f"the library's own sqrt is missing from its exports: {sorted(fx.iface().exports)}"
    );
}

test "the bundled math layout lists every public function it lowers" {
    stdlib = native_stdlib_root();
    assert stdlib is not None , "bundled na_stdlib not found";
    fx = compile_native_ir("math.jac", fixture_dir=stdlib);
    for name in ["sqrt", "sin", "cos", "atan2", "exp", "log", "pow"] {
        assert name in fx.iface().exports , f"math.{name} is missing from the exports";
    }
    missing = demoted_public_functions(fx);
    assert not missing , f"math functions demoted: {missing}";
}

test "an importer lowered after the library in the same process calls its sqrt" {
    # The cold-build order: the compile reaches the library before the unit
    # that imports it, and that unit reads the library's fresh verdict.
    fx = compile_native_ir("layout_clib_name_mid.jac");
    assert not fx.is_demoted("hyp") , (
        "hyp demoted: its call to the library's sqrt was refused as a call "
        f"into a demoted function: {fx.reason('hyp')}"
    );
}

test "jac run lowers the chain natively on a cold cache and again warm" {
    procs = run_in_fresh_dir(2);
    for (label, proc) in zip(["cold", "warm"], procs) {
        assert proc.returncode == 0 , (
            f"{label} run exit {proc.returncode}: {proc.stderr[-900:] or '(no stderr)'}"
        );
        printed = [
            line.strip()
            for line in proc.stdout.splitlines()
            if line.strip()
        ];
        assert printed == ["5.0"] , f"{label} run printed {printed}";
        assert "server codespace" not in proc.stderr , (
            f"{label} run fell back: {proc.stderr[-900:]}"
        );
        assert "native seam" not in proc.stderr , (
            f"{label} run demoted a function: {proc.stderr[-900:]}"
        );
    }
}
