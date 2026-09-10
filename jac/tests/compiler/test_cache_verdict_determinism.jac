"""Cache state must never change a checker verdict (#8239).

An erased distinct type is a check-time brand over a primitive: the checker
enforces it nominally and every lowering erases it, so the verdict on
`type Branded := int` cannot depend on which codespace the module landed in.
Placement in turn cannot depend on whether the pass schedules happened to be
importable at the instant the environment was first probed -- the probe answers
from filesystem facts and memoizes only those, so a module-cache-warm run and a
cold run place (and therefore check) a module identically.

The divergent shape: `out: list[Branded]` fed a raw `int` through
`out.append(k)`. A cold run placed the module native, where the native
pointer/int relaxation in `assign_type` answered before the brand check and the
violation went unreported; a warm run placed the same module on the server and
reported it. Both lanes now report it.
"""

import os;
import jaclang;
import jaclang.compiler.driver.compiler as compiler_mod;
import jaclang.compiler.frontend.unitree as uni;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.passes { Transform }
import from jaclang.compiler.driver.schedules {
    _native_env_memo,
    native_pipeline_available
}

glob BRAND_SRC: str = """
type Branded := int;

def collect(n: int) -> list[Branded] {
    out: list[Branded] = [];
    for k = 0 while k < n with k += 1 {
        out.append(k);
    }
    return out;
}
""",
     BRAND_PATH: str = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "distinct", "_brand_determinism.jac"
     );


"""Check the branded snippet with the codespace forced, reporting E1053 texts."""
def brand_errors(space: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=BRAND_PATH,
        use_str=BRAND_SRC,
        options=CompileOptions(no_cgen=True, force_codespace=space)
    );
    return [
        str(alrt)
        for alrt in prog.errors_had
        if alrt.code is not None and alrt.code.code == "E1053"
    ];
}


"""Check the branded snippet with the codespace inferred, as `jac build` does."""
def inferred_brand_errors -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=BRAND_PATH,
        use_str=BRAND_SRC,
        options=CompileOptions(skip_native_engine=True, suppress_codes=["E5092"])
    );
    return [
        str(alrt)
        for alrt in prog.errors_had
        if alrt.code is not None and alrt.code.code == "E1053"
    ];
}


"""Stand in for an inference schedule that cannot be built at this instant."""
def unbuilt_sched -> list[type[Transform]] {
    return [];
}


"""True when the vendored typeshed stubs the checker needs are on disk."""
def typeshed_on_disk -> bool {
    return os.path.exists(
        os.path.join(
            os.path.dirname(str(jaclang.__file__)),
            "vendor",
            "typeshed",
            "stdlib",
            "builtins.pyi"
        )
    );
}


test "a distinct brand is enforced in every codespace" {
    server_errs = brand_errors("server");
    native_errs = brand_errors("native");
    assert len(server_errs) == 1 , f"server lane: {server_errs}";
    assert "Branded" in server_errs[0] , server_errs[0];
    assert native_errs == server_errs , (
        f"the brand verdict changed with placement: server={server_errs} "
        f"native={native_errs}"
    );
}


test "the native env verdict does not depend on transient schedule state" {
    saved_memo = dict(_native_env_memo);
    saved_sched = compiler_mod.get_analysis_sched;
    try {
        _native_env_memo.clear();
        baseline = native_pipeline_available();
        _native_env_memo.clear();
        compiler_mod.get_analysis_sched = unbuilt_sched;
        degraded = native_pipeline_available();
        assert degraded == baseline , (
            "an unbuildable schedule changed the environment verdict: "
            f"baseline={baseline} degraded={degraded}"
        );
        if typeshed_on_disk() {
            assert "typeshed" not in degraded[1] , (
                f"vendored stubs are present; verdict blamed them: {degraded}"
            );
        }
    } finally {
        compiler_mod.get_analysis_sched = saved_sched;
        _native_env_memo.clear();
        _native_env_memo.update(saved_memo);
    }
}


test "the same source checks the same whichever verdict the probe memoized" {
    saved_memo = dict(_native_env_memo);
    saved_sched = compiler_mod.get_analysis_sched;
    try {
        _native_env_memo.clear();
        native_pipeline_available();
        fresh = inferred_brand_errors();
        _native_env_memo.clear();
        compiler_mod.get_analysis_sched = unbuilt_sched;
        try {
            native_pipeline_available();
        } finally {
            compiler_mod.get_analysis_sched = saved_sched;
        }
        degraded = inferred_brand_errors();
        assert fresh == degraded , (
            f"the checker verdict followed the memoized probe: fresh={fresh} "
            f"degraded={degraded}"
        );
        assert len(fresh) == 1 , f"expected one brand error, got {fresh}";
        assert "Branded" in fresh[0] , fresh[0];
    } finally {
        compiler_mod.get_analysis_sched = saved_sched;
        _native_env_memo.clear();
        _native_env_memo.update(saved_memo);
    }
}
