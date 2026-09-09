"""Typeshed is served through one lens for the life of a process.

Typeshed reaches the checker two ways: as parsed `.pyi` trees, or from the
stub catalog. The catalog used to be activated only by the first compile of
a file outside the compiler tree, so a long-lived `jac check` worker that
started on compiler-tree files parsed stubs as trees, cached their classes
on the compiler-tree dependencies it keeps between files, and then flipped
to the catalog for its first application file. From then on the evaluator's
own `NoneType` (and `TypeVar`, `type`, every prelude class) was a different
record from the ones in every type it had cached, so `x: T | None` never
narrowed, generics stopped binding, and impl bodies reported E1099 / E1053
on lines that pass in isolation. Which files lost depended on the worker's
history, which is the order-dependent `jac check .` failure in CI.

The contract now: any top-level compile for a non-selfhost program decides
the lens up front by activating the catalog, and once stub trees have been
served to a non-selfhost program the catalog stays closed for that process.
None recognition additionally compares class records by canonical identity.
"""
import os;
import subprocess;
import sys;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.jir { get_module_cache_path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.jac0core.stubcat_hook { active, set_active }

glob IMPORTER: str = (
         "import from pathlib { Path }\n"
         "import from jaclang.project.config { get_config }\n"
         "def touch() -> str {\n"
         "    cfg = get_config();\n"
         "    return str(cfg) + str(Path(\"a\") / \"b\");\n"
         "}\n"
     ),
     NARROWER: str = (
         "import from pathlib { Path }\n"
         "import from jaclang.project.config { get_config }\n"
         "def name() -> str {\n"
         "    cfg = get_config();\n"
         "    if cfg {\n"
         "        return str(cfg.project);\n"
         "    }\n"
         "    return str(Path(\"a\") / \"b\");\n"
         "}\n"
     ),
     CHECK_PROBE: str = (
         "import sys\n"
         "import jaclang\n"
         "from jaclang.cli.commands.analysis import check\n"
         "sys.exit(check(paths=sys.argv[1:], jobs='0', nowarn=True))\n"
     );

def _write(dirname: str, stem: str, src: str) -> str {
    path = os.path.join(dirname, stem + ".jac");
    with open(path, "w", encoding="utf-8") as f {
        f.write(src);
    }
    return path;
}

def _stub_keys(hub: dict) -> set[str] {
    return {
        k
        for k in hub.keys()
        if k.endswith(".pyi")
    };
}

def _errors_in(prog: JacProgram, mod_path: str) -> list[str] {
    return [
        str(e.msg)
        for e in prog.errors_had
        if e.loc and e.loc.mod_path == mod_path
    ];
}

obj LensState {
    has compiler: any,
        internal: any,
        saved: tuple postinit,
        stubs_before: set[str] postinit;

    def postinit {
        self.saved = (
            self.compiler.stub_catalog_disabled,
            self.compiler._stub_catalog,
            self.compiler._stub_catalog_tried,
            self.compiler._stub_trees_served,
            active(),

        );
        self.stubs_before = _stub_keys(self.internal.mod.hub);
    }

    def deactivate_catalog {
        set_active(None);
        self.compiler._stub_catalog = None;
        self.compiler._stub_catalog_tried = False;
        self.compiler._stub_trees_served = False;
    }

    def new_stub_trees -> set[str] {
        return _stub_keys(self.internal.mod.hub) - self.stubs_before;
    }

    def restore {
        (
            self.compiler.stub_catalog_disabled,
            self.compiler._stub_catalog,
            self.compiler._stub_catalog_tried,
            self.compiler._stub_trees_served,
            cat,

        ) = self.saved;
        set_active(cat);
        for key in self.new_stub_trees() {
            self.internal.invalidate_module(key);
        }
    }
}

test "a compiler-tree compile activates the catalog instead of parsing stub trees" {
    prog = JacProgram();
    compiler = prog._get_compiler();
    state = LensState(compiler=compiler, internal=compiler.selfhost.program);
    try {
        state.deactivate_catalog();
        target = os.path.join(
            compiler.selfhost.jaclang_root(), "compiler", "driver", "log.jac"
        );
        assert os.path.isfile(target) , f"missing fixture {target}";
        prog.compile(
            file_path=target,
            options=CompileOptions(no_cgen=True, force_target_program=True)
        );
        assert compiler.stub_catalog() is not None , (
            "a non-selfhost compile of a compiler-tree file left the catalog inactive"
        );
        assert not state.new_stub_trees() , (
            f"typeshed was parsed as trees with the catalog available: {sorted(
                state.new_stub_trees()
            )[:4]}"
        );
    } finally {
        prog.release_compile_closure();
        state.restore();
    }
}

test "once stub trees serve a program the catalog stays closed" {
    prog = JacProgram();
    compiler = prog._get_compiler();
    state = LensState(compiler=compiler, internal=compiler.selfhost.program);
    opts = CompileOptions(no_cgen=True, native_parity=True, force_target_program=True);
    try {
        with tempfile.TemporaryDirectory() as d {
            state.deactivate_catalog();
            compiler.stub_catalog_disabled = True;
            first = prog.compile(
                file_path=_write(d, "lens_importer", IMPORTER), options=opts
            );
            assert not _errors_in(prog, first.loc.mod_path) , _errors_in(
                prog, first.loc.mod_path
            );
            assert state.new_stub_trees() , "expected stub trees while the catalog is disabled";
            assert compiler._stub_trees_served , "serving stub trees must mark the process";
            prog.release_compile_closure();
            compiler.stub_catalog_disabled = False;
            assert compiler.ensure_stub_catalog() is None , (
                "the catalog opened after stub trees were served"
            );
            second = prog.compile(
                file_path=_write(d, "lens_narrower", NARROWER), options=opts
            );
            errs = _errors_in(prog, second.loc.mod_path);
            assert not errs , f"the tree lens stopped being self-consistent: {errs}";
        }
    } finally {
        prog.release_compile_closure();
        state.restore();
    }
}

test "None recognition survives a forced lens flip" {
    prog = JacProgram();
    compiler = prog._get_compiler();
    state = LensState(compiler=compiler, internal=compiler.selfhost.program);
    opts = CompileOptions(no_cgen=True, native_parity=True, force_target_program=True);
    try {
        with tempfile.TemporaryDirectory() as d {
            state.deactivate_catalog();
            compiler.stub_catalog_disabled = True;
            first = prog.compile(
                file_path=_write(d, "flip_importer", IMPORTER), options=opts
            );
            assert not _errors_in(prog, first.loc.mod_path) , _errors_in(
                prog, first.loc.mod_path
            );
            prog.release_compile_closure();
            compiler.stub_catalog_disabled = False;
            compiler._stub_trees_served = False;
            assert compiler.ensure_stub_catalog() is not None , (
                "the stub catalog is unavailable, so the flip cannot be staged"
            );
            second = prog.compile(
                file_path=_write(d, "flip_narrower", NARROWER), options=opts
            );
            errs = [
                e
                for e in _errors_in(prog, second.loc.mod_path)
                if "NoneType" in e
            ];
            assert not errs , f"None narrowing depends on record identity: {errs}";
        }
    } finally {
        prog.release_compile_closure();
        state.restore();
    }
}

test "a serial jac check over compiler-tree then client files stays clean" {
    prog = JacProgram();
    pkg = prog._get_compiler().selfhost.jaclang_root();
    files = [
        os.path.join(pkg, "compiler", "driver", "ifacecache.jac"),
        os.path.join(pkg, "client", "targets", "pwa_build.jac")
    ];
    for f in files {
        assert os.path.isfile(f) , f"missing fixture {f}";
        cached = get_module_cache_path(f);
        if cached.exists() {
            cached.unlink();
        }
    }
    env = dict(os.environ);
    env["JAC_CHECK_JOBS"] = "0";
    proc = subprocess.run(
        [sys.executable, "-c", CHECK_PROBE, *files],
        cwd=os.path.dirname(pkg),
        capture_output=True,
        text=True,
        env=env
    );
    assert proc.returncode == 0 , (
        f"jac check regressed on the compiler-tree-then-client order (rc={proc.returncode}):\n"
        f"{proc.stdout[-2500:]}\n{proc.stderr[-1500:]}"
    );
}
