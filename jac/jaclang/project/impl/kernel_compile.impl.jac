impl kernel_compile(
    program: JacProgram, path: str, options: CompileOptions, source: (str | None) = None
) -> CompileReport {
    import time;
    started = time.monotonic();
    import from jaclang.compiler.backends.native.kernel_resolve { load_kernel }
    kernel = load_kernel();
    try {
        result = kernel.compile(compile_request_record(path, options, source));
    } except kernel.KernelError as err {
        raise KernelCompileError(
            f"the native compiler kernel could not compile {path}: {err}"
        ) from err;
    }
    outcome = compile_report_of(result, path);
    sink = os.environ.get(KERNEL_TIMING_ENV, "");
    total = time.monotonic() - started;
    if sink or total > SLOW_COMPILE_SECONDS {
        import sys;
        line = f"jac: kernel compile {path}: {total:.2f}s, {len(outcome.units)} unit(s)\n";
        if os.sep in sink {
            with open(sink, "a", encoding="utf-8") as log {
                log.write(line);
            }
        } else {
            sys.stderr.write(line);
        }
    }
    return outcome;
}

impl kernel_route(program: JacProgram, path: str) -> bool {
    if program.internal or is_compiler_source_path(path) or _HOST_PREPARING {
        return False;
    }
    import from jaclang.compiler.backends.native.kernel_resolve { load_kernel }
    load_kernel();
    return True;
}

impl kernel_compile_reported(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> CompileReport {
    compiled = kernel_compile(program, path, options);
    kernel_trace(
        f"kernel compiled {path}: {len(compiled.units)} unit(s), "
        f"{len(compiled.analysis.errors)} error(s)"
    );
    replay_event_rows(host, compiled.analysis.events);
    for diag in compiled.analysis.errors {
        program.errors_had.append(alert_of(diag));
    }
    for diag in compiled.analysis.warnings {
        program.warnings_had.append(alert_of(diag));
    }
    return compiled;
}

impl kernel_generates_native(program: JacProgram, path: str) -> bool {
    return kernel_route(program, path);
}

impl host_kernel_compile(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    if not kernel_route(program, path) or options.skip_analysis {
        return None;
    }
    ready = _APPLICATION_UNITS.pop(os.path.realpath(path), None);
    if ready is not None {
        return CompileReport(analysis=AnalysisReport(entry_path=path), units=[ready]);
    }
    return kernel_compile_reported(host, program, path, options);
}

impl kernel_compile_application(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    if not kernel_route(program, path) {
        return None;
    }
    compiled = kernel_compile_reported(host, program, path, options);
    for unit in compiled.units {
        _APPLICATION_UNITS[os.path.realpath(unit.path)] = unit;
    }
    return compiled;
}

impl forget_application_units {
    _APPLICATION_UNITS.clear();
}

impl host_preparing(entry_path: str) {
    _HOST_PREPARING.append(entry_path);
}

impl host_prepared {
    _HOST_PREPARING.clear();
}
