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
import from jaclang.compiler.driver.jir { get_module_cache_path }
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
    try {
        os.unlink(get_module_cache_path(path));
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
    target = _tree_path(HYDRATION_TARGET);
    _reset_selfhost();
    cold_prog = JacProgram();
    _check_recomputed(target, cold_prog);
    cold = cold_prog.analysis.pass_runs.get("SymTabBuildPass", 0);
    assert cold >= 8 , (
        f"the cold analysis ingested only {cold} dependency trees, too few to measure"
    );
    _reset_selfhost();
    _forget_verdict(target);
    warm_prog = JacProgram();
    _check(target, warm_prog);
    events = dict(warm_prog.analysis.cache_events);
    warm = warm_prog.analysis.pass_runs.get("SymTabBuildPass", 0);
    assert events.get("dep_hydrate", 0) >= 1 , (
        f"the warm analysis hydrated no compiler-tree dependency (events: {events})"
    );
    assert warm * 4 <= cold , (
        f"the warm analysis re-ingested its dependencies: {warm} symbol-table runs "
        f"against {cold} cold (events: {events})"
    );
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
