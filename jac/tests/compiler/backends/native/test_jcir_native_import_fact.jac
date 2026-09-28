"""The emitter's last driver read becomes a stamped fact (#8288 M1 rung 1).

`JcirGenPass.exit_import` was the one place a sealed pass still reached
for `self.prog`: it asked `native_only_import_target` whether the import
resolved to a module the native lane owns, then asked the filesystem
whether that module lived inside jaclang's own tree. Both are
import-resolution questions -- they need the hub, the placement pins and
`os.path` -- and both are the driver's, which is why the seam coverage
waived the method for exactly that reason.

The driver now answers them once and stamps the verdict on the node, the
way `Module.access_enforced` and `Module.mobui_enforced_root` are
stamped. The pass consumes a bool.

Pinned here: the stamp lands where the coverage says it must (before the
emitter runs), it agrees with the computation it replaced, and the pass
unit no longer names `prog` at all -- the last of the eight driver names
`test_pass_driver_seam_baseline.jac` forbids.
"""

import os;
import subprocess;
import tempfile;
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.boundary_classify {
    import_bound_names,
    native_only_import_target,
    python_side_name_refs
}
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR, jac_command }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     PINNED_IMPORTER = "na_py_interop_multi.jac",
     PKG_PATH = Path(jaclang.__file__).parent,
     ANCHOR_LIB = (
         "import from c { def strlen(s: str) -> i64; }\n\n"
         + "obj Counter {\n    has n: int = 0;\n\n"
         + "    def bump(s: str) {\n        self.n += strlen(s);\n    }\n}\n"
     ),
     ANCHOR_USER = (
         "import from anchor_lib { Counter }\n\n"
         + "obj Holder {\n    has c: Counter = Counter();\n}\n\n"
         + "def fresh_count -> int {\n    return Holder().c.n;\n}\n"
     ),
     ANCHOR_MAIN = (
         "import from anchor_user { fresh_count }\n\n"
         + "with entry {\n    print(fresh_count());\n}\n"
     ),
     # The library also declares a C struct, which the user imports beside
     # `Counter` though only native code could construct it.
     STRUCT_LIB = (
         "import from c {\n    obj Div {\n        has quot: i32,\n"
         + "            rem: i32;\n    }  def div(num: i32, den: i32) -> Div;"
         + "  def strlen(s: str) -> i64;\n}\n\n"
         + "obj Counter {\n    has n: int = 0;\n\n"
         + "    def bump(s: str) {\n        self.n += strlen(s);\n    }\n}\n"
     ),
     STRUCT_USER = (
         "import from anchor_lib { Counter, Div }\n\n"
         + "obj Holder {\n    has c: Counter = Counter();\n}\n\n"
         + "def fresh_count -> int {\n    return Holder().c.n;\n}\n"
     );


"""Compile a fixture as a server module with pinned native sections and hand
back (program, module): the shape whose python side omits the native
functions, so an import only they use has nothing to bind there."""
def _compiled(fixture: str) -> tuple[any, ...] {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions(default_codespace='server')
    );
    return (prog, mod, );
}


test "the driver stamps every import before the emitter reads it" {
    (prog, mod) = _compiled(PINNED_IMPORTER);
    imports = list(mod.get_all_sub_nodes(uni.Import));
    assert imports , f"{PINNED_IMPORTER} has no imports to stamp";
    stamped = [
        imp
        for imp in imports
        if imp.native_only_drop
    ];
    assert stamped , (
        "no import in a module that imports two natively pinned modules "
        "carries the verdict; an unstamped tree makes the emitter drop "
        "nothing, silently"
    );
}


test "the stamped verdict is the computation it replaced" {
    (prog, mod) = _compiled(PINNED_IMPORTER);
    py_refs = python_side_name_refs(mod);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        target = native_only_import_target(imp, prog);
        expected = target is not None
            and (os.sep + "jaclang" + os.sep) not in os.path.abspath(target)
            and not any(name in py_refs for name in import_bound_names(imp));
        assert imp.native_only_drop == expected , (
            f"the stamp and the retired computation disagree for the "
            f"import at line {imp.loc.first_line}: stamped "
            f"{imp.native_only_drop}, computed {expected}"
        );
    }
}

"""Write the anchored-library project: `anchor_lib` declares a C import, so it
is native-only; `anchor_user` is inferred native and names `Counter` in a field
default its Python side evaluates; `main` is pinned to the server."""
def _anchor_project(proj: str, lib: str = ANCHOR_LIB, user: str = ANCHOR_USER) {
    files = {
        "jac.toml": '[project]\nname = "anchor"\n\n[placement.pins]\nmain = "server"\n',
        "anchor_lib.jac": lib,
        "anchor_user.jac": user,
        "main.jac": ANCHOR_MAIN
    };
    for (name, text) in files.items() {
        Path(proj, name).write_text(text, encoding="utf-8");
    }
}

test "an import the python side names survives in an inferred-native module" {
    with tempfile.TemporaryDirectory() as proj {
        _anchor_project(proj);
        prog = JacProgram();
        mod = prog.compile(
            file_path=os.path.join(proj, "anchor_user.jac"), options=CompileOptions()
        );
        imports = [
            imp
            for imp in mod.get_all_sub_nodes(uni.Import)
            if "Counter" in import_bound_names(imp)
        ];
        assert len(imports) == 1 , "anchor_user imports Counter once";
        assert mod.decided_codespace == "native" , (
            f"anchor_user must infer native to exercise the drop; decided "
            f"{mod.decided_codespace!r}"
        );
        assert native_only_import_target(imports[0], prog) is not None , (
            "anchor_lib's C import must make it a native-only target"
        );
        assert not imports[0].native_only_drop , (
            "the python side of anchor_user evaluates `Counter()` in a field "
            "default, so dropping the import leaves the name unbound there"
        );
    }
}

test "a kept import leaves out the C declarations the target's python side lacks" {
    with tempfile.TemporaryDirectory() as proj {
        _anchor_project(proj, STRUCT_LIB, STRUCT_USER);
        prog = JacProgram();
        mod = prog.compile(
            file_path=os.path.join(proj, "anchor_user.jac"), options=CompileOptions()
        );
        imports = [
            imp
            for imp in mod.get_all_sub_nodes(uni.Import)
            if "Counter" in import_bound_names(imp)
        ];
        assert len(imports) == 1 , "anchor_user imports Counter and Div once";
        assert not imports[0].native_only_drop , "the python side names Counter";
        assert imports[0].python_absent_names == {"Div"} , (
            f"Div is declared only in anchor_lib's C import, so the python side "
            f"must not import it; absent {imports[0].python_absent_names!r}"
        );
    }
}

"""Run the anchored project's server-pinned `main` from `proj_dir` and return
its last stdout line."""
def _run_anchor_main(proj_dir: str) -> str {
    proc = subprocess.run(
        jac_command("run", os.path.join(proj_dir, "main.jac")),
        capture_output=True,
        text=True,
        timeout=300,
        cwd=proj_dir
    );
    assert proc.returncode == 0 , proc.stderr[-1200:];
    lines = proc.stdout.strip().splitlines();
    return lines[-1] if lines else "";
}

test "a python caller reaches an inferred-native module's python side" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _anchor_project(proj);
        assert _run_anchor_main(proj) == "0";
    }
}

test "a python caller loads a module importing a C struct from a native one" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _anchor_project(proj, STRUCT_LIB, STRUCT_USER);
        assert _run_anchor_main(proj) == "0";
    }
}

test "the emitter unit no longer names the driver" {
    impl_dir = PKG_PATH / "compiler" / "backends" / "py" / "jcir_gen_pass.impl";
    text = "\n".join(
        f.read_text(encoding="utf-8") for f in sorted(impl_dir.glob("*.impl.jac"))
    );
    assert text , f"no emitter bodies under {impl_dir}";
    assert "self.prog" not in text , (
        "the JCIR emitter reaches for the compile driver again; a sealed "
        "pass cannot, and the driver-seam coverage forbids the name"
    );
    assert "native_only_import_target" not in text , (
        "the emitter resolves import placement itself again instead of "
        "consuming the stamped verdict"
    );
}
