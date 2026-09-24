"""A unit's native layout lists its own functions named after an imported C extern.

A unit's native layout is the export table its importers bind against: a
function missing from `layout.functions` counts as demoted, and a caller
emitted against that layout refuses the call (E5092) and demotes with it.
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
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import jaclang.compiler.frontend.unitree as uni;

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     LAYOUT_FIXTURES: list[str] = [
         "layout_clib_name_main.jac",
         "layout_clib_name_mid.jac",
         "layout_clib_name_lib.jac",
         "layout_clib_name_ffi.jac"
     ];

"""Native IR only, with nothing cached, in the given program."""
def cold_ir_opts -> CompileOptions {
    return CompileOptions(
        force_codespace='native',
        force_target_program=True,
        skip_native_engine=True,
        no_ir_cache=True
    );
}

"""Public, non-generic free functions a module defines."""
def public_functions(module: uni.Module) -> set[str] {
    names: set[str] = set();
    for stmt in ModuleFacts.iter_context_stmts(module) {
        if (
            isinstance(stmt, uni.Ability)
            and stmt.name_ref
            and stmt.body is not None
            and not stmt.type_params
            and isinstance(stmt.signature, uni.FuncSignature)
            and not stmt.name_ref.sym_name.startswith("_")
        ) {
            names.add(stmt.name_ref.sym_name);
        }
    }
    return names;
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
    module = compile_native_ir("layout_clib_name_lib.jac");
    layout = module.gen.native_layout;
    assert layout is not None , "no native layout for the library";
    assert re.search(r'declare [^\n]*@"?sqrt"?\(double', str(module.gen.llvm_ir)) , (
        "the fixture no longer links C's sqrt beside its own"
    );
    assert "sqrt" in layout.functions , (
        f"the library's own sqrt is missing from its layout: {sorted(layout.functions)}"
    );
}

test "the bundled math layout lists every public function it lowers" {
    stdlib = native_stdlib_root();
    assert stdlib is not None , "bundled na_stdlib not found";
    module = compile_native_ir("math.jac", fixture_dir=stdlib);
    layout = module.gen.native_layout;
    assert layout is not None , "no native layout for math";
    for name in ["sqrt", "sin", "cos", "atan2", "exp", "log", "pow"] {
        assert name in layout.functions , f"math.{name} is missing from the layout";
    }
    missing = sorted(public_functions(module) - set(layout.functions));
    assert not missing , f"math functions missing from the layout: {missing}";
}

test "an importer lowered after the library in the same process calls its sqrt" {
    # The cold-build order: the link compiles the library before the unit
    # that imports it, and that unit reads the library's fresh layout.
    prog = JacProgram();
    lib = prog.compile(
        file_path=os.path.join(FIXTURES, "layout_clib_name_lib.jac"),
        options=cold_ir_opts()
    );
    assert lib.gen.native_layout is not None , "the library produced no layout";
    mid = prog.compile(
        file_path=os.path.join(FIXTURES, "layout_clib_name_mid.jac"),
        options=cold_ir_opts()
    );
    assert not prog.errors_had , f"{[e.pretty_print() for e in prog.errors_had]}";
    assert mid.gen.native_layout is not None , "the importer produced no layout";
    assert "hyp" in mid.gen.native_layout.functions , (
        "hyp demoted: its call to the library's sqrt was refused as a call "
        "into a demoted function"
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
