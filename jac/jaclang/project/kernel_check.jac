import os;
import sys;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.kernel_analyze {
    AnalysisDiag,
    AnalysisReport,
    DiagSpan
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.passes.context { Alert }
import from jaclang.project.kernel_snapshot { kernel_analysis }

glob KERNEL_ANALYZE_ENV: str = "JAC_KERNEL_ANALYZE",
     _PASS_TYPES: dict[str, type] = {};

obj KernelCheck {
    has outcome: (AnalysisReport | None) = None,
        adopted: bool = False,
        parity: bool = False,
        failure: str = "";
}

def kernel_analyze_mode -> str {
    raw = os.environ.get(KERNEL_ANALYZE_ENV, "").strip().lower();
    if raw in ("0", "off", "false", "no") {
        return "off";
    }
    if raw == "parity" {
        return "parity";
    }
    return "on";
}

def analysis_kernel -> any {
    if kernel_analyze_mode() == "off" {
        return None;
    }
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None or not hasattr(kernel.lib, "jc_analyze") {
        return None;
    }
    return kernel;
}

def pass_type_named(name: str) -> type {
    found = _PASS_TYPES.get(name);
    if found is not None {
        return found;
    }
    import from jaclang.compiler.passes.context { CompilerPass }
    for (mod_name, mod) in list(sys.modules.items()) {
        if mod is None or not mod_name.startswith("jaclang.compiler.") {
            continue;
        }
        candidate = getattr(mod, name, None);
        if isinstance(candidate, type) and issubclass(candidate, CompilerPass) {
            _PASS_TYPES[name] = candidate;
            return candidate;
        }
    }
    placeholder = type(name or "KernelPass", (CompilerPass, ), {});
    _PASS_TYPES[name] = placeholder;
    return placeholder;
}

def span_of(record: DiagSpan) -> Span {
    return Span(
        mod_path=record.mod_path,
        first_line=record.first_line,
        last_line=record.last_line,
        col_start=record.col_start,
        col_end=record.col_end,
        pos_start=record.pos_start,
        pos_end=record.pos_end,
        src_window=record.src_window,
        window_offset=record.window_offset,
        window_line=record.window_line
    );
}

def alert_of(diag: AnalysisDiag) -> Alert {
    import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
    return Alert(
        msg=diag.msg or diag.message,
        loc=span_of(diag.span),
        from_pass=pass_type_named(diag.pass_name),
        code=DIAGNOSTICS.get(diag.code) if diag.code else None,
        related=[(r.label, span_of(r.span)) for r in diag.related],
        help_text=diag.help_text,
        owner=diag.owner
    );
}

def alert_row(alert: Alert) -> tuple[str, str, int, int] {
    loc = alert.loc;
    code = alert.code.code if alert.code is not None else "";
    path = os.path.realpath(loc.mod_path) if loc.mod_path else "";
    return (code, path, loc.first_line, loc.col_start);
}

def diag_row(diag: AnalysisDiag) -> tuple[str, str, int, int] {
    path = os.path.realpath(diag.path) if diag.path else "";
    return (diag.code, path, diag.line, diag.col);
}

def kernel_check(
    program: JacProgram, path: str, options: CompileOptions
) -> KernelCheck {
    import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }
    if is_compiler_source_path(path) {
        return KernelCheck();
    }
    mode = kernel_analyze_mode();
    kernel = analysis_kernel();
    if kernel is None {
        return KernelCheck();
    }
    try {
        outcome = kernel_analysis(active_host(), program, path, options);
    } except Exception as err {
        return KernelCheck(
            parity=mode == "parity", failure=f"{type(err).__name__}: {err}"
        );
    }
    entry_module = outcome.module(path);
    if entry_module is None or entry_module.native {
        return KernelCheck(outcome=outcome);
    }
    if mode == "parity" {
        return KernelCheck(outcome=outcome, parity=True);
    }
    for diag in outcome.errors {
        program.errors_had.append(alert_of(diag));
    }
    for diag in outcome.warnings {
        program.warnings_had.append(alert_of(diag));
    }
    return KernelCheck(outcome=outcome, adopted=True);
}

def parity_mismatches(
    check: KernelCheck, errors: list[Alert], warnings: list[Alert]
) -> list[str] {
    if check.failure {
        return [f"kernel analysis failed: {check.failure}"];
    }
    outcome = check.outcome;
    if outcome is None {
        return [];
    }
    out: list[str] = [];
    for (label, host_rows, kernel_rows) in (
        (
            "error",
            sorted(alert_row(a) for a in errors),
            sorted(diag_row(d) for d in outcome.errors)
        ),
        (
            "warning",
            sorted(alert_row(a) for a in warnings),
            sorted(diag_row(d) for d in outcome.warnings)
        )
    ) {
        for row in host_rows {
            if row not in kernel_rows {
                out.append(f"{label} only on the host: {row}");
            }
        }
        for row in kernel_rows {
            if row not in host_rows {
                out.append(f"{label} only in the kernel: {row}");
            }
        }
    }
    return out;
}

def report_parity(
    check: KernelCheck, path: str, errors: list[Alert], warnings: list[Alert]
) -> list[str] {
    mismatches = parity_mismatches(check, errors, warnings);
    if mismatches {
        stream = sys.__stderr__ or sys.stderr;
        stream.write(f"kernel analysis parity: {path}\n");
        for line in mismatches {
            stream.write(f"  {line}\n");
        }
    }
    return mismatches;
}

def reached_modules(outcome: AnalysisReport) -> list[str] {
    return [m.path for m in outcome.modules];
}
