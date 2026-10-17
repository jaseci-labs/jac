glob _native_env_memo: dict[str, tuple[bool, str]] = {};

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    if schedule_loading() {
        return (True, '');
    }
    try {
        import from jaclang.artifacts.router { resolve }
        resolution = resolve("llvm-shim");
        if resolution.deferred {
            return (
                False,
                'native pipeline undecided: the compiler is still initializing'
            );
        }
    } except ModuleNotFoundError {
        return (False, 'native pipeline unavailable: the artifact router is missing');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return (False, 'native pipeline undecided: the compiler is still initializing');
    }
    reason = (
        ''
            if resolution.found is not None
            else f'native pipeline unavailable: the LLVM shim is {resolution.reason}'
    );
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}
