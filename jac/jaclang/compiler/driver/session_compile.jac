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
    has nested: bool = False;
}

obj SessionHooks {
    def enter_compile(ctx: SessionContext) -> CompileFrame;
    def leave_compile(ctx: SessionContext, frame: CompileFrame);
    def finish_compile(frame: CompileFrame);
    def check_crash(crash: Exception, file_path: str);
    def closure_options -> (CompileOptions | None);
    def compile(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module;

    def compile_attempt(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module;

    def assemble_python(program: JacProgram, module: uni.Module);
    def assemble_native(program: JacProgram, module: uni.Module, checking: bool);
    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module abst;
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
    hooks: SessionHooks,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module;

def compile_attempts(
    hooks: SessionHooks,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module;

def compile_once(
    hooks: SessionHooks,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module;

def drop_native_bindings(mod: uni.Module, resolved: str);
