import os;

obj SessionContext {
    has caller: JacProgram,
        target: JacProgram,
        options: CompileOptions,
        errors_mark: int = 0,
        warnings_mark: int = 0;

    def merge_alerts;
}

obj CompileFrame {
    has depth_prev: int = 0,
        gc_prev: (tuple[int, int, int] | None) = None,
        retain_selfhost: bool = False;
}

def select_context(
    file_path: str, program: JacProgram, options: CompileOptions
) -> SessionContext;

def annex_parent(
    file_path: str, program: JacProgram, use_str: (str | None), options: CompileOptions
) -> (str | None);

def inherit_session_options(
    program: JacProgram, options: CompileOptions, closure: (CompileOptions | None)
) -> CompileOptions;

def compile_in_session(
    compiler: JacCompiler,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module;

def compile_once(
    compiler: JacCompiler,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module;

def drop_native_bindings(mod: uni.Module, resolved: str);
