import os;
import sys;

glob _PASS_TYPES: dict[str, type] = {},
     _STAND_INS: dict[str, type] = {};

obj KernelCheck {
    has outcome: (AnalysisReport | None) = None,
        adopted: bool = False,
        parity: bool = False,
        failure: str = "";
}

class KernelCheckError(RuntimeError) {}

def analysis_kernel -> any;

def loaded_pass_type(name: str) -> (type | None);

def pass_type_named(name: str) -> type;

def span_of(record: DiagSpan) -> Span;

def alert_of(diag: AnalysisDiag) -> Alert;

def alert_row(alert: Alert) -> tuple[str, str, int, int];

def diag_row(diag: AnalysisDiag) -> tuple[str, str, int, int];

def kernel_check(
    program: JacProgram, path: str, options: CompileOptions, parity: bool = False
) -> KernelCheck;

def shown(
    diags: list[AnalysisDiag], keep: (Callable[[Alert], bool] | None)
) -> list[AnalysisDiag];

def parity_mismatches(
    check: KernelCheck,
    errors: list[Alert],
    warnings: list[Alert],
    keep: (Callable[[Alert], bool] | None) = None
) -> list[str];

def report_parity(
    check: KernelCheck,
    path: str,
    errors: list[Alert],
    warnings: list[Alert],
    keep: (Callable[[Alert], bool] | None) = None
) -> list[str];

def reached_modules(outcome: AnalysisReport) -> list[str];
