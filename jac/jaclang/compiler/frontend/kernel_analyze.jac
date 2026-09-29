import json;
import os;
import sys;
import from jaclang.compiler.driver.module_analysis { ModuleAnalysis }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host {
    active_host,
    install_host,
    set_package_root
}
import from jaclang.compiler.frontend.kernel_host { KernelHost }
import from jaclang.compiler.frontend.kernel_inputs {
    KernelInputs,
    json_int,
    json_map,
    json_maps,
    json_opt_str,
    json_str_list
}
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.srcloc { Span }
import from jaclang.compiler.passes.context { Alert }

glob ANALYSIS_OK: int = 0,
     ANALYSIS_BLOCKED: int = 1,
     ANALYSIS_CRASHED: int = 3;

obj DiagSpan {
    has mod_path: str = "",
        first_line: int = 0,
        last_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        src_window: str = "",
        window_offset: int = 0,
        window_line: int = 0;

    def to_dict -> dict[str, any] {
        return {
            "mod_path": self.mod_path,
            "first_line": self.first_line,
            "last_line": self.last_line,
            "col_start": self.col_start,
            "col_end": self.col_end,
            "pos_start": self.pos_start,
            "pos_end": self.pos_end,
            "src_window": self.src_window,
            "window_offset": self.window_offset,
            "window_line": self.window_line
        };
    }
}

obj RelatedDiag {
    has label: str = "",
        span: DiagSpan = DiagSpan();
}

obj AnalysisDiag {
    has code: str = "",
        message: str = "",
        path: str = "",
        line: int = 0,
        col: int = 0,
        pass_name: str = "",
        msg: str = "",
        span: DiagSpan = DiagSpan(),
        related: list[RelatedDiag] = [],
        help_text: (str | None) = None,
        owner: str = "";

    def to_dict -> dict[str, any] {
        return {
            "code": self.code,
            "message": self.message,
            "path": self.path,
            "line": self.line,
            "col": self.col,
            "pass": self.pass_name,
            "msg": self.msg,
            "span": self.span.to_dict(),
            "related": [
                {"label": r.label, "span": r.span.to_dict()} for r in self.related
            ],
            "help_text": self.help_text,
            "owner": self.owner
        };
    }
}

obj ModuleReport {
    has path: str,
        parse_failed: bool = False,
        blocked: bool = False,
        native: bool = False,
        passes: list[str] = [];

    def to_dict -> dict[str, any] {
        return {
            "path": self.path,
            "parse_failed": self.parse_failed,
            "blocked": self.blocked,
            "native": self.native,
            "passes": list(self.passes)
        };
    }
}

obj AnalysisReport {
    has status: int = ANALYSIS_OK,
        message: str = "",
        entry_path: str = "",
        modules: list[ModuleReport] = [],
        errors: list[AnalysisDiag] = [],
        warnings: list[AnalysisDiag] = [],
        misses: list[str] = [];

    def module(path: str) -> (ModuleReport | None) {
        resolved = os.path.realpath(path);
        for candidate in self.modules {
            if candidate.path == resolved {
                return candidate;
            }
        }
        return None;
    }

    def to_json -> str {
        return json.dumps(
            {
                "status": self.status,
                "message": self.message,
                "entry": self.entry_path,
                "modules": [m.to_dict() for m in self.modules],
                "errors": [d.to_dict() for d in self.errors],
                "warnings": [d.to_dict() for d in self.warnings],
                "misses": list(self.misses)
            },
            sort_keys=True
        );
    }

    static def from_json(text: str) -> AnalysisReport {
        raw = json_map(json.loads(text));
        return AnalysisReport(
            status=json_int(raw.get("status"), ANALYSIS_CRASHED),
            message=str(raw.get("message", "")),
            entry_path=str(raw.get("entry", "")),
            modules=[module_from_dict(m) for m in json_maps(raw.get("modules"))],
            errors=[diag_from_dict(d) for d in json_maps(raw.get("errors"))],
            warnings=[diag_from_dict(d) for d in json_maps(raw.get("warnings"))],
            misses=json_str_list(raw.get("misses"))
        );
    }
}

def module_from_dict(raw: dict[str, any]) -> ModuleReport {
    return ModuleReport(
        path=str(raw.get("path", "")),
        parse_failed=bool(raw.get("parse_failed", False)),
        blocked=bool(raw.get("blocked", False)),
        native=bool(raw.get("native", False)),
        passes=json_str_list(raw.get("passes"))
    );
}

def span_from_dict(raw: dict[str, any]) -> DiagSpan {
    return DiagSpan(
        mod_path=str(raw.get("mod_path", "")),
        first_line=json_int(raw.get("first_line")),
        last_line=json_int(raw.get("last_line")),
        col_start=json_int(raw.get("col_start")),
        col_end=json_int(raw.get("col_end")),
        pos_start=json_int(raw.get("pos_start")),
        pos_end=json_int(raw.get("pos_end")),
        src_window=str(raw.get("src_window", "")),
        window_offset=json_int(raw.get("window_offset")),
        window_line=json_int(raw.get("window_line"))
    );
}

def span_record(span: Span) -> DiagSpan {
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

def diag_from_dict(raw: dict[str, any]) -> AnalysisDiag {
    return AnalysisDiag(
        code=str(raw.get("code", "")),
        message=str(raw.get("message", "")),
        path=str(raw.get("path", "")),
        line=json_int(raw.get("line")),
        col=json_int(raw.get("col")),
        pass_name=str(raw.get("pass", "")),
        msg=str(raw.get("msg", "")),
        span=span_from_dict(json_map(raw.get("span"))),
        related=[
            RelatedDiag(
                label=str(r.get("label", "")),
                span=span_from_dict(json_map(r.get("span")))
            ) for r in json_maps(raw.get("related"))
        ],
        help_text=json_opt_str(raw.get("help_text")),
        owner=str(raw.get("owner", ""))
    );
}

def diag_of(alert: Alert) -> AnalysisDiag {
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

def module_report(task: ModuleAnalysis) -> ModuleReport {
    done = task.program.analysis.completed_passes.get(id(task.module));
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

def analysis_report(
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

def kernel_trace(message: str) {
    if os.environ.get("JAC_KERNEL_TRACE") {
        sys.stderr.write(f"[kernel] {message}\n");
        sys.stderr.flush();
    }
}

def run_kernel_analysis(
    inputs_json: str, path: str, source: (str | None)
) -> AnalysisReport {
    kernel_trace("decode inputs");
    try {
        inputs = KernelInputs.from_json(inputs_json);
    } except Exception as err {
        return AnalysisReport(
            status=ANALYSIS_CRASHED,
            message=f"undecodable kernel inputs: {err}",
            entry_path=path
        );
    }
    if inputs.package_root {
        set_package_root(inputs.package_root);
    }
    host = KernelHost(inputs=inputs);
    host.census.trace = bool(os.environ.get("JAC_KERNEL_TRACE"));
    previous = active_host();
    install_host(host);
    program = JacProgram();
    status = ANALYSIS_OK;
    message = "";
    kernel_trace(f"analyze {path}");
    try {
        options = inputs.request.to_options();
        host.compile_module(program, path, source, options);
    } except Exception as err {
        status = ANALYSIS_CRASHED;
        message = f"{type(err).__name__}: {err}";
    } finally {
        install_host(previous);
    }
    kernel_trace(f"report status {status}");
    outcome = analysis_report(
        program, path, list(host.analyses.values()), status, message
    );
    outcome.misses.extend(host.census.miss_keys);
    return outcome;
}
