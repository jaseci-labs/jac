import json;
import os;
import from jaclang.compiler.driver.module_analysis { ModuleAnalysis }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.host { active_host, install_host }
import from jaclang.compiler.frontend.kernel_host { KernelHost }
import from jaclang.compiler.frontend.kernel_inputs { KernelInputs }
import from jaclang.compiler.passes.context { Alert }

glob ANALYSIS_OK: int = 0,
     ANALYSIS_BLOCKED: int = 1,
     ANALYSIS_CRASHED: int = 3;

obj AnalysisDiag {
    has code: str = "",
        message: str = "",
        path: str = "",
        line: int = 0,
        col: int = 0,
        pass_name: str = "";

    def to_dict -> dict[str, any] {
        return {
            "code": self.code,
            "message": self.message,
            "path": self.path,
            "line": self.line,
            "col": self.col,
            "pass": self.pass_name
        };
    }
}

obj ModuleReport {
    has path: str,
        parse_failed: bool = False,
        blocked: bool = False,
        passes: list[str] = [];

    def to_dict -> dict[str, any] {
        return {
            "path": self.path,
            "parse_failed": self.parse_failed,
            "blocked": self.blocked,
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
        raw: dict[str, any] = json.loads(text);
        return AnalysisReport(
            status=int(raw.get("status", ANALYSIS_CRASHED)),
            message=str(raw.get("message", "")),
            entry_path=str(raw.get("entry", "")),
            modules=[module_from_dict(m) for m in raw.get("modules", [])],
            errors=[diag_from_dict(d) for d in raw.get("errors", [])],
            warnings=[diag_from_dict(d) for d in raw.get("warnings", [])],
            misses=[str(m) for m in raw.get("misses", [])]
        );
    }
}

def module_from_dict(raw: dict[str, any]) -> ModuleReport {
    return ModuleReport(
        path=str(raw["path"]),
        parse_failed=bool(raw.get("parse_failed", False)),
        blocked=bool(raw.get("blocked", False)),
        passes=[str(p) for p in raw.get("passes", [])]
    );
}

def diag_from_dict(raw: dict[str, any]) -> AnalysisDiag {
    return AnalysisDiag(
        code=str(raw.get("code", "")),
        message=str(raw.get("message", "")),
        path=str(raw.get("path", "")),
        line=int(raw.get("line", 0)),
        col=int(raw.get("col", 0)),
        pass_name=str(raw.get("pass", ""))
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
        pass_name=source.__name__ if source is not None else ""
    );
}

def module_report(task: ModuleAnalysis) -> ModuleReport {
    done = task.program.analysis.completed_passes.get(id(task.module));
    return ModuleReport(
        path=os.path.realpath(task.path),
        parse_failed=task.parse_failed,
        blocked=task.blocked,
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

def run_kernel_analysis(
    inputs_json: str, path: str, source: (str | None)
) -> AnalysisReport {
    inputs = KernelInputs.from_json(inputs_json);
    host = KernelHost(inputs=inputs);
    previous = active_host();
    install_host(host);
    program = JacProgram();
    status = ANALYSIS_OK;
    message = "";
    try {
        options = inputs.request.to_options();
        host.compile_module(program, path, source, options);
    } except Exception as err {
        status = ANALYSIS_CRASHED;
        message = f"{type(err).__name__}: {err}";
    } finally {
        install_host(previous);
    }
    outcome = analysis_report(
        program, path, list(host.analyses.values()), status, message
    );
    outcome.misses.extend(host.census.miss_keys);
    return outcome;
}
