"""The compiler's own tree is an ordinary citizen of the analysis cache.

Two properties, asserted through the self-host program's counters rather than
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
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.session.cache.artifact_codec { get_module_cache_path }
import from jaclang.compiler.session.session { JacProgram }
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
    try {
        os.unlink(get_module_cache_path(path));
    } except OSError {}
}

def _check(path: str) -> list[str] {
    prog = _selfhost() if path.startswith(JACLANG_DIR + os.sep) else JacProgram();
    prog.compile(
        path,
        options=CompileOptions(
            no_cgen=True, native_parity=True, force_target_program=True, iface_ok=True
        )
    );
    return sorted(
        a.pretty_print()
        for a in prog.errors_had + prog.warnings_had
        if prog.diags._owned(a, path)
    );
}

def _check_recomputed(path: str) -> list[str] {
    saved = os.environ.get("JAC_REBUILD");
    os.environ["JAC_REBUILD"] = "1";
    try {
        return _check(path);
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
    import jaclang.compiler.pipeline.executor as driver;
    target = _tree_path(HYDRATION_TARGET);
    dependency = _tree_path('server/serving/app.jac');
    paths: set[str] = set();
    original: any = getattr(driver, 'run_pass');
    def record(pass_cls: any, ir_in: any, prog: any, **kwargs: any) -> any {
        if pass_cls == PassIdentity.SymTabBuildPass and prog is _selfhost() {
            paths.add(os.path.realpath(ir_in.loc.mod_path));
        }
        return original(pass_cls, ir_in, prog, **kwargs);
    }
    # Measure actual dependency reuse, independently of how many duplicate
    # compilations a cold pipeline happens to perform.
    _check(target);
    with patch.object(driver, 'run_pass', record) {
        _reset_selfhost();
        _check_recomputed(target);
        cold = set(paths);
        assert dependency in cold , cold;
        paths.clear();
        _reset_selfhost();
        _forget_verdict(target);
        _check(target);
    }
    events = dict(_selfhost().analysis.cache_events);
    assert events.get("dep_hydrate", 0) >= 1 , (
        f"the warm analysis hydrated no compiler-tree dependency (events: {events})"
    );
    assert dependency not in paths , f'cached dependency was rebuilt: {paths}';
    assert len(paths) < len(cold) , (paths, cold, events);
}

test "a verdict served warm is the verdict a cold analysis computes, across the compiler tree" {
    for rel in ORACLE_SAMPLE {
        target = _tree_path(rel);
        _reset_selfhost();
        _check(target);
        _reset_selfhost();
        _forget_verdict(target);
        hydrated = _check(target);
        events = dict(_selfhost().analysis.cache_events);
        assert events.get("dep_hydrate", 0) >= 1 , (
            f"{rel}: nothing hydrated, so the comparison is vacuous (events: {events})"
        );
        _reset_selfhost();
        recomputed = _check_recomputed(target);
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
        cold = _check_recomputed(str(source));
        warm = _check(str(source));
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
    compiler_source = _tree_path('compiler/pipeline/schedule.jac');
    assert compiler.selfhost.resolve(compiler_source, program)
        is compiler.selfhost.program;
}


test "interface lookup preserves the requesting compilation context" {
    path = _tree_path('server/serving/datatypes.jac');
    program = JacProgram();
    options = CompileOptions(
        no_cgen=True, native_parity=True, force_target_program=True, iface_ok=True
    );
    program.compile(path, options=options);
    assert not program.errors_had , [str(error) for error in program.errors_had];
    registry = program.iface_registry();
    iface_entry = registry.ensure(path);
    assert iface_entry is not None;
    assert registry.entries[path] is iface_entry;
    assert program is not _selfhost();
    program.release_compile_closure(collect=False);
}
