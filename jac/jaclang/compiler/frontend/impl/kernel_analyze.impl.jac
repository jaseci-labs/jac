impl AnalysisReport.module(path: str) -> (ModuleReport | None) {
    resolved = os.path.realpath(path);
    for candidate in self.modules {
        if candidate.path == resolved {
            return candidate;
        }
    }
    return None;
}

impl span_record(span: Span) -> DiagSpan {
    return DiagSpan(
        mod_path=span.mod_path,
        first_line=span.first_line,
        last_line=span.last_line,
        col_start=span.col_start,
        col_end=span.col_end,
        pos_start=span.pos_start,
        pos_end=span.pos_end,
        src_window=span.src_window,
        window_offset=span.window_offset,
        window_line=span.window_line
    );
}

impl diag_of(alert: Alert) -> AnalysisDiag {
    loc = alert.loc;
    code = alert.code;
    source = alert.from_pass;
    lines = alert.msg.split("\n");
    return AnalysisDiag(
        code=code.code if code is not None else "",
        message=lines[0] if lines else "",
        path=loc.mod_path,
        line=loc.first_line,
        col=loc.col_start,
        pass_name=source.__name__ if source is not None else "",
        msg=alert.msg,
        span=span_record(loc),
        related=[
            RelatedDiag(label=label, span=span_record(where))
            for (label, where) in alert.related
        ],
        help_text=alert.help_text,
        owner=alert.owner
    );
}

impl module_report(task: ModuleAnalysis) -> ModuleReport {
    build = task.program.analysis.peek(task.module);
    done = build.done if build is not None else None;
    native = task.native
        or (
            not task.parse_failed and ModuleFacts.has_native_context_stmts(task.module)
        );
    return ModuleReport(
        path=os.path.realpath(task.path),
        parse_failed=task.parse_failed,
        blocked=task.blocked,
        native=native,
        passes=sorted(done) if done is not None else []
    );
}

impl analysis_report(
    program: JacProgram,
    entry_path: str,
    tasks: list[ModuleAnalysis],
    status: int,
    message: str
) -> AnalysisReport {
    outcome = AnalysisReport(
        status=status, message=message, entry_path=os.path.realpath(entry_path)
    );
    for task in tasks {
        outcome.modules.append(module_report(task));
    }
    for alert in program.errors_had {
        outcome.errors.append(diag_of(alert));
    }
    for alert in program.warnings_had {
        outcome.warnings.append(diag_of(alert));
    }
    if status == ANALYSIS_OK {
        entry_module = outcome.module(entry_path);
        if entry_module is not None and entry_module.blocked {
            outcome.status = ANALYSIS_BLOCKED;
        }
    }
    return outcome;
}

impl kernel_trace(message: str) {
    if os.environ.get("JAC_KERNEL_TRACE") {
        sys.stderr.write(f"[kernel] {message}\n");
        sys.stderr.flush();
    }
}

impl KernelRun.outcome(entry_path: str) -> AnalysisReport {
    outcome = analysis_report(
        self.program,
        entry_path,
        list(self.host.analyses.values()),
        self.status,
        self.message
    );
    outcome.misses.extend(self.host.census.miss_keys);
    outcome.events = self.host.event_rows();
    outcome.reads = [
        [path, digest] for (path, digest) in self.host.source_reads.items()
    ];
    return outcome;
}

impl run_kernel_session(
    inputs: KernelInputs,
    path: str,
    source: (str | None),
    with_codegen: bool,
    asker: (HostAsker | None) = None,
    kernel_asker: bool = False
) -> KernelRun {
    if inputs.package_root {
        set_package_root(inputs.package_root);
    }
    host = KernelHost(inputs=inputs, asker=asker, kernel_asker=kernel_asker);
    host.census.trace = bool(os.environ.get("JAC_KERNEL_TRACE"));
    run = KernelRun(host=host, program=JacProgram());
    previous = active_host();
    host.loader = previous;
    install_host(host);
    kernel_trace(f"{'compile' if with_codegen else 'analyze'} {path}");
    try {
        options = inputs.request.to_options();
        if with_codegen {
            host.close_over(options);
        }
        host.compile_module(run.program, path, source, options);
        if with_codegen {
            listed: set[str] = set();
            for emit_path in inputs.emit_paths {
                listed.add(os.path.realpath(emit_path));
            }
            tried: set[str] = set();
            tried.add(os.path.realpath(path));
            emitted = True;
            while emitted {
                emitted = False;
                reached: list[str] = [];
                for analysed in host.analyses {
                    reached.append(analysed);
                }
                for real in reached {
                    if real in tried or real in host.units {
                        continue;
                    }
                    tried.add(real);
                    if real not in listed and not host.wants_unit(real) {
                        continue;
                    }
                    host.compile_module(run.program, real, None, options);
                    emitted = True;
                }
            }
        }
    } except Exception as err {
        run.status = ANALYSIS_CRASHED;
        run.message = f"{type(err).__name__}: {err}";
        running = run.program.analysis.running;
        if running is not None {
            where = running.pass_name;
            visiting = running.current_node;
            if visiting is not None and visiting.loc {
                loc = visiting.loc;
                where += f" at {loc.mod_path}:{loc.first_line}:{loc.col_start}";
            }
            run.message += f" (in {where})";
        }
    } finally {
        install_host(previous);
    }
    kernel_trace(f"report status {run.status}");
    return run;
}

impl CompileReport.unit(path: str) -> (UnitProducts | None) {
    resolved = os.path.realpath(path);
    for candidate in self.units {
        if os.path.realpath(candidate.path) == resolved {
            return candidate;
        }
    }
    return None;
}
