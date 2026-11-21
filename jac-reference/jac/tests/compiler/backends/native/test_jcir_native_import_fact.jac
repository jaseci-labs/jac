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
     SPAN_LIB = (
         "import from c {\n    obj Span {\n        has lo: i64,\n            hi: i64;\n    }\n"
         + "    def labs(x: i64) -> i64;\n}\n\n"
         + "obj Meter {\n    has n: int = 0;\n\n"
         + "    def add(x: int) {\n        self.n += int(labs(x));\n    }\n}\n"
     ),
     SPAN_USER = (
         "import from span_lib { Meter, Span }\n\n"
         + "def span_width(s: Span) -> int {\n    return int(s.hi - s.lo);\n}\n\n"
         + "def measured(x: int) -> int {\n    m = Meter();\n    m.add(x);\n    return m.n;\n}\n"
     ),
     EMBED_DECL = (
         "import from c {\n    obj Inner {\n        has lo: i64,\n            hi: i64;\n    }\n"
         + "    def labs(x: i64) -> i64;\n}\n\n"
         + "def inner_width(lo: int, hi: int) -> int {\n    return int(labs(hi - lo));\n}\n"
     ),
     EMBED_USER = (
         "import from embed_decl { Inner }\nimport from embed_decl { inner_width }\n"
         + "import from c {\n    obj Outer {\n        has count: i64,\n            inner: Inner;\n    }\n"
         + "    def llabs(x: i64) -> i64;\n}\n\n"
         + "obj Holder {\n    has outer: Outer | None = None,\n        n: int = 3;\n}\n\n"
         + "def held(x: int) -> int {\n    return Holder().n + int(llabs(x)) + inner_width(2, 7);\n}\n"
     ),
     EMBED_BARE_DECL = (
         "import from c {\n    obj Inner {\n        has lo: i64,\n            hi: i64;\n    }\n}\n"
     ),
     EMBED_MAIN = (
         "import from embed_user { held }\n\n"
         + "with entry {\n    print(held(-4));\n}\n"
     ),
     SPAN_TESTS = (
         "import from span_user { measured }\n\n"
         + 'test "a C struct re-exported by an inferred-native module" {\n'
         + "    assert measured(-5) == 5;\n}\n"
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
        expected = (
            bool(imp.clib_decls)
            or (
                target is not None
                and (os.sep + "jaclang" + os.sep) not in os.path.abspath(target)
            )
        )
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
def _anchor_project(proj: str) {
    files = {
        "jac.toml": '[project]\nname = "anchor"\n\n[placement.pins]\nmain = "server"\n',
        "anchor_lib.jac": ANCHOR_LIB,
        "anchor_user.jac": ANCHOR_USER,
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

test "a C-anchored module infers native under a server default" {
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    with tempfile.TemporaryDirectory() as proj {
        _anchor_project(proj);
        prior = get_effective_default_codespace_override();
        set_effective_default_codespace('server');
        try {
            prog = JacProgram();
            options = CompileOptions(default_codespace='server', no_cgen=True);
            lib = prog.compile(
                file_path=os.path.join(proj, "anchor_lib.jac"), options=options
            );
            user = prog.compile(
                file_path=os.path.join(proj, "anchor_user.jac"), options=options
            );
        } finally {
            set_effective_default_codespace(prior);
        }
        assert lib.decided_codespace == "native" , (
            "anchor_lib's C import pins it native whatever the default, so it "
            f"keeps its python side; decided {lib.decided_codespace!r}"
        );
        assert user.decided_codespace != "native" , "anchor_user has no anchor of its own";
    }
}

test "a python caller reaches an inferred-native module's python side" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _anchor_project(proj);
        assert _run_anchor_main(proj) == "0";
    }
}

"""Write the C-declaring project: `span_lib` declares a C struct and function
its own methods use; `span_user` is inferred native and re-exports the struct
in a signature its Python side emits; `span_tests` imports it from Python."""
def _span_project(proj: str) {
    files = {
        "jac.toml": '[project]\nname = "span"\n',
        "span_lib.jac": SPAN_LIB,
        "span_user.jac": SPAN_USER,
        "span_tests.jac": SPAN_TESTS
    };
    for (name, text) in files.items() {
        Path(proj, name).write_text(text, encoding="utf-8");
    }
}

test "a C block whose declarations the python side names is kept there" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _span_project(proj);
        prog = JacProgram();
        mod = prog.compile(
            file_path=os.path.join(proj, "span_lib.jac"), options=CompileOptions()
        );
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        blocks = [
            imp
            for imp in mod.get_all_sub_nodes(uni.Import)
            if imp.clib_decls
        ];
        assert len(blocks) == 1;
        assert import_bound_names(blocks[0]) == ["Span", "labs"];
        assert not blocks[0].native_only_drop , (
            "Meter.add calls labs on span_lib's python side, so dropping the C "
            "block leaves labs (and the Span a python importer names) unbound"
        );
    }
    # A server module's pinned native sections keep theirs to themselves.
    (prog, pinned) = _compiled(PINNED_IMPORTER);
    for imp in pinned.get_all_sub_nodes(uni.Import) {
        if imp.clib_decls {
            assert imp.native_only_drop;
        }
    }
}

test "a python importer binds a C struct re-exported by an inferred-native module" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _span_project(proj);
        proc = subprocess.run(
            jac_command("test", os.path.join(proj, "span_tests.jac")),
            capture_output=True,
            text=True,
            timeout=600,
            cwd=proj
        );
        assert proc.returncode == 0 , (proc.stdout + proc.stderr)[-1500:];
    }
}

"""Write the embedding project: `embed_decl` declares the C record `Inner`;
`embed_user` declares `Outer`, which holds an `Inner` by value, and names
`Outer` (never `Inner`) in code its Python side emits; `main` is pinned to
the server, so it reaches `embed_user` through that Python side."""
def _embed_project(proj: str, alias: str = "", bare: bool = False) {
    user = EMBED_USER;
    if bare {
        user = user.replace("import from embed_decl { inner_width }\n", "").replace(
            " + inner_width(2, 7)", ""
        );
        assert "inner_width" not in user;
    }
    if alias {
        user = user.replace("{ Inner }", f"{{ Inner as {alias} }}").replace(
            "inner: Inner", f"inner: {alias}"
        );
        assert user != EMBED_USER;
    }
    files = {
        "jac.toml": '[project]\nname = "embed"\n\n[placement.pins]\nmain = "server"\n',
        "embed_decl.jac": EMBED_BARE_DECL if bare else EMBED_DECL,
        "embed_user.jac": user,
        "main.jac": EMBED_MAIN
    };
    for (name, text) in files.items() {
        Path(proj, name).write_text(text, encoding="utf-8");
    }
}

test "an import a kept C block's declarations are typed by is kept with it" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _embed_project(proj);
        prog = JacProgram();
        mod = prog.compile(
            file_path=os.path.join(proj, "embed_user.jac"), options=CompileOptions()
        );
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        assert "Inner" not in python_side_name_refs(mod) , (
            "the premise is gone: embed_user's python side names Inner itself"
        );
        blocks = [
            imp
            for imp in mod.get_all_sub_nodes(uni.Import)
            if imp.clib_decls
        ];
        assert len(blocks) == 1 and not blocks[0].native_only_drop , (
            "Holder names Outer on embed_user's python side, so its C block stays"
        );
        inner = [
            imp
            for imp in mod.get_all_sub_nodes(uni.Import)
            if "Inner" in import_bound_names(imp)
        ];
        assert len(inner) == 1;
        assert not inner[0].native_only_drop , (
            "the kept C block binds Outer as it loads, and Outer holds an Inner: "
            "dropping the import leaves `Inner` unbound there"
        );
    }
}

test "a python caller binds a C record that embeds another module's record" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        _embed_project(proj);
        # Holder().n + llabs(-4) + labs(7 - 2).
        assert _run_anchor_main(proj) == "12";
    }
}

test "a python caller binds an embedded C record imported under another name" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        # `import from embed_decl { Inner as Held }` binds only `Held` on the
        # Python side, so the record's descriptor has to name its field's
        # type the way the module spells it.
        _embed_project(proj, alias="Held");
        assert _run_anchor_main(proj) == "12";
    }
}

test "a module that only declares a C record still binds it on its python side" {
    with tempfile.TemporaryDirectory() as tmp {
        proj = os.path.realpath(tmp);
        # `embed_decl` holds nothing but the record: no statement on its
        # Python side names `Inner`, yet another module's kept C block does.
        _embed_project(proj, bare=True);
        prog = JacProgram();
        mod = prog.compile(
            file_path=os.path.join(proj, "embed_decl.jac"), options=CompileOptions()
        );
        assert mod.decided_codespace == "native" , mod.decided_codespace;
        assert not python_side_name_refs(mod) , (
            "the premise is gone: embed_decl's python side names something"
        );
        blocks = [
            imp
            for imp in mod.get_all_sub_nodes(uni.Import)
            if imp.clib_decls
        ];
        assert len(blocks) == 1 and not blocks[0].native_only_drop , (
            "a record is a name other modules import: its block stays bound"
        );
        # Holder().n + llabs(-4).
        assert _run_anchor_main(proj) == "7";
    }
}

test "a python-side C binding loads its library when a function is first called" {
    import from jaclang.runtime.cinterop { clib_bind }
    import json;
    desc = {
        "lib": {"path": "/nonexistent/libjac_missing_for_test.dylib"},
        "structs": [
            {"name": "Pair", "fields": [["a", ["s", "i32"]], ["b", ["s", "i32"]]]}
        ],
        "opaque": [],
        "functions": [
            {"name": "missing_fn", "params": [], "ret": ["void"], "variadic": False}
        ]
    };
    bound = clib_bind({"__file__": ""}, json.dumps(desc));
    pair = bound["Pair"]();
    pair.a = 3;
    assert pair.a == 3;
    raised = False;
    try {
        bound["missing_fn"]();
    } except ImportError {
        raised = True;
    }
    assert raised , "calling into an unloadable library must say so";
}

test "a python-side C binding finds a system library by its bare name" {
    import from jaclang.runtime.cinterop { clib_bind }
    import json;
    # `import from c { ... }` names the library `c`. Where the file that name
    # spells out is not the library itself (glibc's `libc.so` is a linker
    # script), the binding asks the system which file the name means.
    desc = {
        "lib": {"names": ["c"], "level": 0},
        "structs": [],
        "opaque": [],
        "functions": [
            {
                "name": "labs",
                "params": [["x", ["s", "i64"]]],
                "ret": ["s", "i64"],
                "variadic": False
            }
        ]
    };
    bound = clib_bind({"__file__": ""}, json.dumps(desc));
    assert bound["labs"](-7) == 7;
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
