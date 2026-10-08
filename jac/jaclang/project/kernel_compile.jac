import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { HostServices }
import from jaclang.compiler.driver.unit_products { UnitProducts }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    AnalysisReport,
    CompileReport,
    ModuleReport,
    kernel_trace,
    run_kernel_compile
}
import from jaclang.project.kernel_snapshot {
    COMPILE_ENTRY,
    KernelAnalysisError,
    call_with_asker,
    host_deferred,
    _IFACE_BUILT,
    other_compiler_report,
    kernel_snapshot,
    loaded_kernel
}

glob KERNEL_COMPILE_ENV: str = "JAC_KERNEL_COMPILE",
     KERNEL_TIMING_ENV: str = "JAC_KERNEL_TIMING",
     SLOW_COMPILE_SECONDS: float = 20.0,
     _APPLICATION_UNITS: dict[str, UnitProducts] = {},
     _HOST_PREPARING: list[str] = [];

class KernelCompileError(RuntimeError) {}

def kernel_compile_in_process -> bool {
    raw = os.environ.get(KERNEL_COMPILE_ENV, "").strip().lower();
    return raw in ("inprocess", "in-process");
}

def with_ambient_codespace(options: CompileOptions) -> CompileOptions {
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override
    }
    ambient = get_effective_default_codespace_override();
    if options.default_codespace or not ambient {
        return options;
    }
    import copy;
    bound = copy.copy(options);
    bound.default_codespace = ambient;
    return bound;
}

def kernel_compile(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False,
    isolated: bool = True,
    emit_closure: bool = False,
    emit_cached: bool = True
) -> CompileReport {
    import time;
    started = time.monotonic();
    options = with_ambient_codespace(options);
    snapshot = kernel_snapshot(
        host, program, path, options, emit_closure=emit_closure, emit_cached=emit_cached
    );
    seeded = time.monotonic();
    if snapshot.other_compiler {
        outcome = CompileReport(
            analysis=other_compiler_report(path, snapshot.other_compiler)
        );
    } elif in_process {
        outcome = run_kernel_compile(snapshot.text(), path, source, snapshot);
    } else {
        kernel = loaded_kernel(COMPILE_ENTRY);
        outcome = CompileReport.from_json(
            call_with_asker(kernel, COMPILE_ENTRY, snapshot, path, source, isolated)
        );
    }
    analysis = outcome.analysis;
    sink = os.environ.get(KERNEL_TIMING_ENV, "");
    total = time.monotonic() - started;
    if sink or total > SLOW_COMPILE_SECONDS {
        import sys;
        line = f"jac: kernel compile {path}: {total:.2f}s "
        f"(inputs {seeded - started:.2f}s, kernel {total - (seeded - started):.2f}s, "
        f"{len(outcome.units)} unit(s), deferred={host_deferred(analysis)}; "
        f"this process has built {int(_IFACE_BUILT[0])} interfaces in "
        f"{_IFACE_BUILT[1]:.2f}s)\n";
        if os.sep in sink {
            with open(sink, "a", encoding="utf-8") as log {
                log.write(line);
            }
        } else {
            sys.stderr.write(line);
        }
    }
    if host_deferred(analysis) {
        return CompileReport(
            analysis=AnalysisReport(
                entry_path=path,
                modules=[ModuleReport(path=os.path.realpath(path), native=True)]
            )
        );
    }
    if analysis.status == ANALYSIS_CRASHED {
        detail = f" ({analysis.misses[-1]})" if analysis.misses else "";
        raise KernelAnalysisError(analysis.message + detail + snapshot.failure_note());
    }
    if analysis.misses {
        raise KernelAnalysisError(
            f"the kernel lacked host answers ({analysis.misses[0]})"
                + snapshot.failure_note()
        );
    }
    return outcome;
}

def kernel_route(program: JacProgram, path: str) -> tuple[bool, bool] {
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
    if program.internal or is_compiler_source_path(path) or _HOST_PREPARING {
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
    emit_closure: bool,
    emit_cached: bool = True
) -> CompileReport {
    try {
        compiled = kernel_compile(
            host,
            program,
            path,
            options,
            in_process=in_process,
            emit_closure=emit_closure,
            emit_cached=emit_cached
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
    import from jaclang.compiler.frontend.kernel_host { replay_event_rows }
    replay_event_rows(host, compiled.analysis.events);
    import from jaclang.project.kernel_check { alert_of }
    for diag in compiled.analysis.errors {
        program.errors_had.append(alert_of(diag));
    }
    for diag in compiled.analysis.warnings {
        program.warnings_had.append(alert_of(diag));
    }
    return compiled;
}

def kernel_generates_native(program: JacProgram, path: str) -> bool {
    return kernel_route(program, path)[0];
}

def host_kernel_compile(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    (routed, in_process) = kernel_route(program, path);
    if not routed or options.skip_analysis {
        return None;
    }
    ready = _APPLICATION_UNITS.pop(os.path.realpath(path), None);
    if ready is not None {
        return CompileReport(analysis=AnalysisReport(entry_path=path), units=[ready]);
    }
    return kernel_compile_reported(
        host, program, path, options, in_process, True, emit_cached=False
    );
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

def host_preparing(entry_path: str) {
    _HOST_PREPARING.append(entry_path);
}

def host_prepared {
    _HOST_PREPARING.clear();
}
