import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { HostServices }
import from jaclang.compiler.driver.unit_products { UnitProducts }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    AnalysisReport,
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

glob KERNEL_COMPILE_ENV: str = "JAC_KERNEL_COMPILE",
     _APPLICATION_UNITS: dict[str, UnitProducts] = {};

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
    isolated: bool = True,
    emit_closure: bool = False
) -> CompileReport {
    inputs_json = kernel_inputs_json(
        host, program, path, options, source, emit_closure=emit_closure
    );
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

def kernel_route(program: JacProgram, path: str) -> tuple[bool, bool] {
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
    if program.internal or is_compiler_source_path(path) {
        return (False, False);
    }
    if kernel_compile_in_process() {
        return (True, True);
    }
    import from jaclang.compiler.native_compiler { ensure_loaded }
    return (ensure_loaded() is not None, False);
}

def kernel_compile_reported(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    in_process: bool,
    emit_closure: bool
) -> CompileReport {
    try {
        compiled = kernel_compile(
            host,
            program,
            path,
            options,
            in_process=in_process,
            emit_closure=emit_closure
        );
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

def host_kernel_compile(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    (routed, in_process) = kernel_route(program, path);
    if not routed {
        return None;
    }
    ready = _APPLICATION_UNITS.pop(os.path.realpath(path), None);
    if ready is not None {
        return CompileReport(analysis=AnalysisReport(entry_path=path), units=[ready]);
    }
    return kernel_compile_reported(host, program, path, options, in_process, False);
}

def kernel_compile_application(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    (routed, in_process) = kernel_route(program, path);
    if not routed {
        return None;
    }
    compiled = kernel_compile_reported(host, program, path, options, in_process, True);
    for unit in compiled.units {
        _APPLICATION_UNITS[os.path.realpath(unit.path)] = unit;
    }
    return compiled;
}

def forget_application_units {
    _APPLICATION_UNITS.clear();
}
