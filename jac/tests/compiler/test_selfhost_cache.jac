"""The compiler's own tree is an ordinary citizen of the analysis cache.

Two properties, asserted through each analysis program's counters rather than
timing: a compiler-tree dependency hydrates from its persisted interface for
every later analysis instead of being re-ingested as a tree, and a verdict
served warm is byte-for-byte the verdict a cold analysis computes. The second
is the license for the first to exist, and it walks a sample of compiler-tree
files chosen for what they exercise: comptime specs that must reach through a
hydrated boundary, and cross-module attribute types on hydrated classes.

Both tests reset the process-global self-host program between steps, which
is what a fresh process does; other tests in the same worker recompile on
demand, the hub being transient by contract."""
import os;
import jaclang;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.runtime.runtime { JacRuntime }

glob JACLANG_DIR: str = os.path.dirname(os.path.realpath(str(jaclang.__file__))),
     HYDRATION_TARGET: str = "server/serving/openapi.jac",
     ORACLE_SAMPLE: list[str] = [
         "cli/commands/execution.jac",
         "server/serving/openapi.jac",
         "server/serving/coerce.jac",
         "server/session.jac"
     ];

def _tree_path(rel: str) -> str {
    return os.path.realpath(os.path.join(JACLANG_DIR, rel));
}

def _selfhost -> JacProgram {
    return JacRuntime.get_compiler().selfhost.program;
}

def _reset_selfhost {
    sh = _selfhost();
    sh.release_compile_closure(collect=False);
    sh.analysis.pass_runs.clear();
    sh.analysis.cache_events.clear();
}

def _forget_verdict(path: str) {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    import from jaclang.compiler.driver.ifacecache { artifact_cache_path }
    prog = JacProgram();
    options = bind_options(
        path, prog, CompileOptions(no_cgen=True, native_parity=True, iface_ok=True)
    );
    actual = context_program(prog, options);
    try {
        os.unlink(artifact_cache_path(path, actual));
    } except OSError {}
}

def _check(path: str, prog: JacProgram) -> list[str] {
    prog.compile(
        path, options=CompileOptions(no_cgen=True, native_parity=True, iface_ok=True)
    );
    return sorted(
        [a.pretty_print() for a in prog.diags.owned_errors(path)]
            + [a.pretty_print() for a in prog.diags.owned_warnings(path)]
    );
}

def _check_recomputed(path: str, prog: JacProgram) -> list[str] {
    saved = os.environ.get("JAC_REBUILD");
    os.environ["JAC_REBUILD"] = "1";
    try {
        return _check(path, prog);
    } finally {
        if saved is None {
            del os.environ["JAC_REBUILD"];
        } else {
            os.environ["JAC_REBUILD"] = saved;
        }
    }
}

test "a compiler-tree analysis hydrates its dependencies instead of re-ingesting them" {
    import from unittest.mock { patch }
    import jaclang.compiler.driver.pass_driver as driver;
    target = _tree_path(HYDRATION_TARGET);
    dependency = _tree_path('server/serving/app.jac');
    paths: set[str] = set();
    active = [JacProgram()];
    original: any = getattr(driver, 'run_pass');
    def record(pass_cls: any, ir_in: any, prog: any, **kwargs: any) -> any {
        if pass_cls.__name__ == 'SymTabBuildPass' and prog is active[0] {
            paths.add(os.path.realpath(ir_in.loc.mod_path));
        }
        return original(pass_cls, ir_in, prog, **kwargs);
    }
    _check(target, JacProgram());
    with patch.object(driver, 'run_pass', record) {
        _reset_selfhost();
        _check_recomputed(target, active[0]);
        cold = set(paths);
        assert dependency in cold , cold;
        paths.clear();
        _reset_selfhost();
        _forget_verdict(target);
        active[0] = JacProgram();
        _check(target, active[0]);
    }
    events = dict(active[0].analysis.cache_events);
    assert events.get("dep_hydrate", 0) >= 1 , events;
    assert dependency not in paths , f'cached dependency was rebuilt: {paths}';
    assert len(paths) < len(cold) , (paths, cold, events);
}

test "a verdict served warm is the verdict a cold analysis computes, across the compiler tree" {
    for rel in ORACLE_SAMPLE {
        target = _tree_path(rel);
        _reset_selfhost();
        warm_prog = JacProgram();
        _check(target, warm_prog);
        _reset_selfhost();
        _forget_verdict(target);
        warm_prog = JacProgram();
        hydrated = _check(target, warm_prog);
        events = dict(warm_prog.analysis.cache_events);
        assert events.get("dep_hydrate", 0) >= 1 , (
            f"{rel}: nothing hydrated, so the comparison is vacuous (events: {events})"
        );
        _reset_selfhost();
        cold_prog = JacProgram();
        recomputed = _check_recomputed(target, cold_prog);
        assert hydrated == recomputed , (
            f"{rel}: the warm verdict differs from the cold one\n"
            f"hydrated ({len(hydrated)}):\n"
            + "\n".join(hydrated)
            + f"\nrecomputed ({len(recomputed)}):\n"
            + "\n".join(recomputed)
        );
    }
}


test "variadic tuple annotations resolve ellipsis on cold and warm checks" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    with TemporaryDirectory() as td {
        (Path(td) / 'values.jac').write_text(
            'def:pub values -> tuple[int, ...] { return (1, 2); }\n'
        );
        source = Path(td) / 'main.jac';
        source.write_text(
            'import from values { values }\ndef:pub first -> int { return values()[0]; }\n'
        );
        cold = _check_recomputed(str(source), JacProgram());
        warm = _check(str(source), JacProgram());
        assert not any(
            'error[' in diagnostic or 'W1051' in diagnostic for diagnostic in cold
        ) , cold;
        assert warm == cold;
    }
}


test "bundled app dependencies retain their compilation context" {
    compiler = JacRuntime.get_compiler();
    program = JacProgram();
    app_source = _tree_path('scale/admin/ui/constants/users.jac');
    assert compiler.selfhost.resolve(app_source, program) is program;
    compiler_source = _tree_path('compiler/driver/pipeline.jac');
    assert compiler.selfhost.resolve(compiler_source, program)
        is compiler.selfhost.program;
}

test "executing a compiler-tree module leaves the program's own context unclaimed" {
    compiler = JacRuntime.get_compiler();
    program = JacProgram();
    compiler.get_native_interop_setup(
        _tree_path('compiler/driver/pipeline.jac'), program
    );
    compiler.get_native_layout(_tree_path('compiler/driver/pipeline.jac'), program);
    assert not program.context_key;
    assert not program.contexts;
}
