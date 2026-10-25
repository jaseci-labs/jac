impl run_kernel_in_process(on: bool = True) -> bool {
    previous = kernel_compile_in_process();
    _IN_PROCESS.clear();
    if on {
        _IN_PROCESS.append(True);
    }
    return previous;
}

impl kernel_compile_in_process -> bool {
    return bool(_IN_PROCESS);
}

impl kernel_compile(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False,
    isolated: bool = True,
    emit_closure: bool = False,
    emit_cached: bool = True,
    seeds: (list[PythonInterface] | None) = None
) -> (CompileReport | None) {
    import time;
    started = time.monotonic();
    snapshot = kernel_snapshot(
        host,
        program,
        path,
        options,
        emit_closure=emit_closure,
        emit_cached=emit_cached,
        seeds=seeds
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
        return None;
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

impl kernel_route(program: JacProgram, path: str) -> tuple[bool, bool] {
    if program.internal or is_compiler_source_path(path) or _HOST_PREPARING {
        return (False, False);
    }
    if kernel_compile_in_process() {
        return (True, True);
    }

    if ensure_loaded() is None {
        import from jaclang.compiler.backends.native.kernel_resolve {
            refuse_unloadable
        }
        refuse_unloadable();
        return (False, False);
    }
    return (True, False);
}

impl kernel_compile_reported(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    in_process: bool,
    emit_closure: bool,
    emit_cached: bool = True,
    seeds: (list[PythonInterface] | None) = None
) -> (CompileReport | None) {
    try {
        compiled = kernel_compile(
            host,
            program,
            path,
            options,
            in_process=in_process,
            emit_closure=emit_closure,
            emit_cached=emit_cached,
            seeds=seeds
        );
    } except KernelAnalysisError as err {
        raise KernelCompileError(
            f"the native compiler kernel could not compile {path}: {err}"
        ) from err;
    }
    if compiled is None {
        return None;
    }
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
    return kernel_route(program, path)[0];
}

impl host_kernel_compile(
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

impl kernel_compile_application(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    seeds: (list[PythonInterface] | None) = None
) -> (CompileReport | None) {
    (routed, in_process) = kernel_route(program, path);
    if not routed {
        return None;
    }
    compiled = kernel_compile_reported(
        host, program, path, options, in_process, True, seeds=seeds
    );
    if compiled is None {
        return None;
    }
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
