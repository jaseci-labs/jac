impl kernel_check(
    program: JacProgram,
    path: str,
    options: CompileOptions,
    native_coverage: bool = False,
    placements: bool = False,
    closure: bool = False
) -> CheckResult {
    result = call_check(
        check_request_for([path], options, native_coverage, placements, closure)
    );
    adopt_diagnostics(program, result.errors, result.warnings);
    return result;
}
