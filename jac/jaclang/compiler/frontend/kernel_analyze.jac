import json;
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

    def to_dict -> dict[str, any];
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

    def to_dict -> dict[str, any];
}

obj ModuleReport {
    has path: str,
        parse_failed: bool = False,
        blocked: bool = False,
        native: bool = False,
        passes: list[str] = [];

    def to_dict -> dict[str, any];
}

obj AnalysisReport {
    has status: int = ANALYSIS_OK,
        message: str = "",
        entry_path: str = "",
        modules: list[ModuleReport] = [],
        errors: list[AnalysisDiag] = [],
        warnings: list[AnalysisDiag] = [],
        misses: list[str] = [],
        events: list[list[str]] = [];

    def module(path: str) -> (ModuleReport | None);
    def to_dict -> dict[str, any];
    def to_json -> str;
    static def from_json(text: str) -> AnalysisReport;
    static def from_dict(raw: dict[str, any]) -> AnalysisReport;
}

def json_str_pairs_of(value: object) -> list[list[str]];

def module_from_dict(raw: dict[str, any]) -> ModuleReport;

def span_from_dict(raw: dict[str, any]) -> DiagSpan;

def span_record(span: Span) -> DiagSpan;

def diag_from_dict(raw: dict[str, any]) -> AnalysisDiag;

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

def decode_inputs(inputs_json: str) -> (KernelInputs | str);

def run_kernel_analysis(
    inputs_json: str,
    path: str,
    source: (str | None),
    asker: (HostAsker | None) = None,
    kernel_asker: bool = False
) -> AnalysisReport;

obj CompileReport {
    has analysis: AnalysisReport,
        units: list[UnitProducts] = [];

    def unit(path: str) -> (UnitProducts | None);
    def to_json -> str;
    static def from_json(text: str) -> CompileReport;
}

def run_kernel_compile(
    inputs_json: str,
    path: str,
    source: (str | None),
    asker: (HostAsker | None) = None,
    kernel_asker: bool = False
) -> CompileReport;
