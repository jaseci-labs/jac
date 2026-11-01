import os;
import sys;

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
}

obj ModuleReport {
    has path: str,
        parse_failed: bool = False,
        blocked: bool = False,
        native: bool = False,
        passes: list[str] = [];
}

obj AnalysisReport {
    has status: int = ANALYSIS_OK,
        message: str = "",
        entry_path: str = "",
        modules: list[ModuleReport] = [],
        errors: list[AnalysisDiag] = [],
        warnings: list[AnalysisDiag] = [],
        misses: list[str] = [],
        events: list[list[str]] = [],
        reads: list[list[str]] = [];

    def module(path: str) -> (ModuleReport | None);
}

def span_record(span: Span) -> DiagSpan;

def diag_of(alert: Alert) -> AnalysisDiag;

def module_report(task: ModuleAnalysis) -> ModuleReport;

def analysis_report(
    program: JacProgram,
    entry_path: str,
    tasks: list[ModuleAnalysis],
    status: int,
    message: str
) -> AnalysisReport;

def kernel_trace(message: str);

obj KernelRun {
    has host: KernelHost,
        program: JacProgram,
        status: int = ANALYSIS_OK,
        message: str = "";

    def outcome(entry_path: str) -> AnalysisReport;
}

def run_kernel_session(
    inputs: KernelInputs,
    path: str,
    source: (str | None),
    with_codegen: bool,
    asker: (HostAsker | None) = None,
    kernel_asker: bool = False
) -> KernelRun;

obj CompileReport {
    has analysis: AnalysisReport,
        units: list[UnitProducts] = [];

    def unit(path: str) -> (UnitProducts | None);
}
