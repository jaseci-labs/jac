import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { HostServices }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    CompileReport,
    kernel_trace,
    run_kernel_compile
}
import from jaclang.project.kernel_snapshot {
    COMPILE_ENTRY,
    KernelAnalysisError,
    call_kernel,
    call_kernel_isolated,
    kernel_inputs_json,
    loaded_kernel
}

glob KERNEL_COMPILE_ENV: str = "JAC_KERNEL_COMPILE";

class KernelCompileError(RuntimeError) {}

def kernel_compile_in_process -> bool {
    raw = os.environ.get(KERNEL_COMPILE_ENV, "").strip().lower();
    return raw in ("inprocess", "in-process");
}

def kernel_compile(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False,
    isolated: bool = True
) -> CompileReport {
    inputs_json = kernel_inputs_json(host, program, path, options, source);
    if in_process {
        outcome = run_kernel_compile(inputs_json, path, source);
    } else {
        kernel = loaded_kernel(COMPILE_ENTRY);
        call = call_kernel_isolated if isolated else call_kernel;
        outcome = CompileReport.from_json(
            call(kernel, COMPILE_ENTRY, inputs_json, path, source)
        );
    }
    analysis = outcome.analysis;
    if analysis.status == ANALYSIS_CRASHED {
        detail = f" ({analysis.misses[-1]})" if analysis.misses else "";
        raise KernelAnalysisError(analysis.message + detail);
    }
    if analysis.misses {
        raise KernelAnalysisError(
            f"the kernel lacked host answers ({analysis.misses[0]})"
        );
    }
    return outcome;
}

def host_kernel_compile(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
    if program.internal or is_compiler_source_path(path) {
        return None;
    }
    in_process = kernel_compile_in_process();
    if not in_process {
        import from jaclang.compiler.native_compiler { ensure_loaded }
        if ensure_loaded() is None {
            return None;
        }
    }
    try {
        compiled = kernel_compile(host, program, path, options, in_process=in_process);
    } except KernelAnalysisError as err {
        raise KernelCompileError(
            f"the native compiler kernel could not compile {path}: {err}"
        ) from err;
    }
    kernel_trace(
        f"kernel compiled {path}: {len(compiled.units)} unit(s), "
        f"{len(compiled.analysis.errors)} error(s)"
    );
    import from jaclang.project.kernel_check { alert_of }
    for diag in compiled.analysis.errors {
        program.errors_had.append(alert_of(diag));
    }
    for diag in compiled.analysis.warnings {
        program.warnings_had.append(alert_of(diag));
    }
    return compiled;
}
