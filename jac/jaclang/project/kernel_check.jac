import os;
import sys;

glob KERNEL_ANALYZE_ENV: str = "JAC_KERNEL_ANALYZE",
     _PASS_TYPES: dict[str, type] = {},
     _STAND_INS: dict[str, type] = {};

obj KernelCheck {
    has outcome: (AnalysisReport | None) = None,
        adopted: bool = False,
        parity: bool = False,
        failure: str = "";
}

class KernelCheckError(RuntimeError) {}

def kernel_analyze_mode -> str {
    raw = os.environ.get(KERNEL_ANALYZE_ENV, "").strip().lower();
    return "parity" if raw == "parity" else "on";
}

def analysis_kernel -> any {
    kernel = ensure_loaded();
    if kernel is None or not hasattr(kernel.lib, "jc_analyze") {
        return None;
    }
    return kernel;
}

def loaded_pass_type(name: str) -> (type | None) {
    for (mod_name, mod) in list(sys.modules.items()) {
        if mod is None or not mod_name.startswith("jaclang.compiler.") {
            continue;
        }
        candidate = getattr(mod, name, None);
        if isinstance(candidate, type) and issubclass(candidate, CompilerPass) {
            return candidate;
        }
    }
    return None;
}

def pass_type_named(name: str) -> type {
    found = _PASS_TYPES.get(name);
    if found is not None {
        return found;
    }
    found = loaded_pass_type(name);
    if found is not None {
        _PASS_TYPES[name] = found;
        return found;
    }
    stand_in = _STAND_INS.get(name);
    if stand_in is None {
        import from jaclang.compiler.passes.context { CompilerPass }
        stand_in = type(name or "KernelPass", (CompilerPass, ), {});
        _STAND_INS[name] = stand_in;
    }
    return stand_in;
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
    if is_compiler_source_path(path) {
        return KernelCheck();
    }
    mode = kernel_analyze_mode();
    kernel = analysis_kernel();
    if kernel is None {
        return KernelCheck();
    }
    try {
        outcome = kernel_analysis(active_host(), program, path, options, isolated=True);
    } except Exception as err {
        if mode != "parity" {
            raise KernelCheckError(
                f"the native compiler kernel could not analyze {path}: "
                f"{type(err).__name__}: {err}"
            ) from err;
        }
        return KernelCheck(parity=True, failure=f"{type(err).__name__}: {err}");
    }
    if host_deferred(outcome) {
        return KernelCheck(outcome=outcome);
    }
    if outcome.misses {
        failure = f"the kernel lacked host answers ({outcome.misses[0]})";
        if mode != "parity" {
            raise KernelCheckError(
                f"the native compiler kernel could not analyze {path}: {failure}"
            );
        }
        return KernelCheck(outcome=outcome, parity=True, failure=failure);
    }
    entry_module = outcome.module(path);
    if entry_module is None {
        raise KernelCheckError(
            f"the native compiler kernel analyzed {path} but reported no module for it"
        );
    }
    if entry_module.native {
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

def shown(
    diags: list[AnalysisDiag], keep: (Callable[[Alert], bool] | None)
) -> list[AnalysisDiag] {
    if keep is None {
        return diags;
    }
    return [
        d
        for d in diags
        if keep(alert_of(d))
    ];
}

def parity_mismatches(
    check: KernelCheck,
    errors: list[Alert],
    warnings: list[Alert],
    keep: (Callable[[Alert], bool] | None) = None
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
            sorted(diag_row(d) for d in shown(outcome.errors, keep))
        ),
        (
            "warning",
            sorted(alert_row(a) for a in warnings),
            sorted(diag_row(d) for d in shown(outcome.warnings, keep))
        )
    ) {
        for row in host_rows {
            if row not in kernel_rows and not is_compiler_source_path(row[1]) {
                out.append(f"{label} only on the host: {row}");
            }
        }
        for row in kernel_rows {
            if row not in host_rows and not is_compiler_source_path(row[1]) {
                out.append(f"{label} only in the kernel: {row}");
            }
        }
    }
    return out;
}

def report_parity(
    check: KernelCheck,
    path: str,
    errors: list[Alert],
    warnings: list[Alert],
    keep: (Callable[[Alert], bool] | None) = None
) -> list[str] {
    mismatches = parity_mismatches(check, errors, warnings, keep);
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
