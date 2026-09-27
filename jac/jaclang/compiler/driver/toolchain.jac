import from contextvars { ContextVar }
import from jaclang.compiler.driver.pipeline {
    _analysis_sched_loading,
    _ir_sched_loading
}
import from jaclang.compiler.driver.source_failures { fail_loud_on_compiler_source }

glob _native_env_memo: dict[str, tuple[bool, str]] = {},
     _codegen_sched_loading: ContextVar[bool] = ContextVar(
         'jac_codegen_sched_loading', `default=False
     );

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    if (
        _analysis_sched_loading.get()
        or _ir_sched_loading.get()
        or _codegen_sched_loading.get()
    ) {
        return (True, '');
    }
    reason = '';
    try {
        import from jaclang.compiler.backends.native.llvm { _find_shim }
        _find_shim();
    } except ModuleNotFoundError {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return (False, 'native pipeline undecided: the compiler is still initializing');
    } except Exception {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    }
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}
