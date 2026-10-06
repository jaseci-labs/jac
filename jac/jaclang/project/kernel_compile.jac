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
    call_kernel,
    call_kernel_isolated,
    host_deferred,
    _IFACE_BUILT,
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

def miss_context(misses: list[str], inputs_json: str) -> str {
    import json;
    miss = misses[0];
    asked = miss.partition(": ")[2].replace("\\", "/");
    if "/vendor/typeshed/" not in asked {
        return "";
    }
    import from jaclang.compiler.frontend.host { package_root }
    import from jaclang.project.modresolver { get_typeshed_paths }
    stub_dir = asked.rpartition("/")[0];
    reached: list[str] = [];
    try {
        for row in json.loads(inputs_json).get("imports", []) {
            found = str(row.get("path", "")).replace("\\", "/");
            if found.startswith(stub_dir) and len(reached) < 3 {
                reached.append(f"{row.get('target')} from {row.get('base_path')}");
            }
        }
    } except (ValueError, AttributeError) {}
    return f"; compiler package at {package_root()}, stubs at {get_typeshed_paths()}, "
    f"imports resolved there: {reached}, misses: {misses[:5]}";
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
    import time;
    started = time.monotonic();
    snapshot = kernel_snapshot(
        host, program, path, options, source, emit_closure=emit_closure
    );
    snapped = time.monotonic();
    in_kernel = 0.0;
    while True {
        inputs_json = snapshot.text();
        called = time.monotonic();
        if in_process {
            outcome = run_kernel_compile(inputs_json, path, source);
        } else {
            kernel = loaded_kernel(COMPILE_ENTRY);
            call = call_kernel_isolated if isolated else call_kernel;
            outcome = CompileReport.from_json(
                call(kernel, COMPILE_ENTRY, inputs_json, path, source)
            );
        }
        in_kernel += time.monotonic() - called;
        analysis = outcome.analysis;
        if not analysis.misses
            or host_deferred(analysis)
            or not snapshot.answer(analysis.misses) {
            break;
        }
    }
    sink = os.environ.get(KERNEL_TIMING_ENV, "");
    total = time.monotonic() - started;
    if sink or total > SLOW_COMPILE_SECONDS {
        import sys;
        inputs = snapshot.inputs();
        line = f"jac: kernel compile {path}: {total:.2f}s "
        f"(snapshot {snapped - started:.2f}s over {inputs.scanned_modules} modules "
        f"and {len(inputs.python_ifaces)} interfaces, kernel {in_kernel:.2f}s, "
        f"answers {total - (snapped - started) - in_kernel:.2f}s in "
        f"{snapshot.rounds} round(s), deferred={host_deferred(analysis)}; "
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
        raise KernelAnalysisError(analysis.message + detail);
    }
    if analysis.misses {
        raise KernelAnalysisError(
            f"the kernel lacked host answers ({analysis.misses[0]})"
                + miss_context(analysis.misses, inputs_json)
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
    entry_report = compiled.analysis.module(path);
    if entry_report is not None and entry_report.native {
        return compiled;
    }
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
    if not routed or options.skip_analysis {
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

def host_preparing(entry_path: str) {
    _HOST_PREPARING.append(entry_path);
}

def host_prepared {
    _HOST_PREPARING.clear();
}
