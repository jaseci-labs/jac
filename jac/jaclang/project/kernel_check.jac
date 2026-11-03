"""The host's check entry: `jac check` asks the in-process kernel."""

def kernel_check(
    program: JacProgram,
    path: str,
    options: CompileOptions,
    native_coverage: bool = False,
    placements: bool = False,
    closure: bool = False
) -> CheckResult;
