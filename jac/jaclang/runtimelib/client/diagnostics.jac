"""Diagnostics module for client build error reporting."""
import os;
import from pathlib { Path }

glob BOX_H = "─",
     BOX_V = "│",
     BOX_TL = "┌",
     BOX_TR = "┐",
     BOX_BL = "└",
     BOX_BR = "┘",
     WIDTH = 70;

"""Severity level for diagnostics."""
enum Severity {
    ERROR = "error",
    WARNING = "warning",
    INFO = "info"
}

"""Single diagnostic result from a detector."""
obj Diagnostic {
    has code: str = "",
        severity: Severity = Severity.ERROR,
        title: str = "",
        message: str = "",
        file_path: str = "",
        line: int = 0,
        column: int = 0,
        source_snippet: str = "",
        hint: str = "",
        quick_fix: str = "";
}

"""Context passed to all detectors during analysis."""
obj BuildContext {
    has error_output: str = "",
        source_map: dict[str, str] = {},
        project_dir: Path = Path("."),
        jac_files: list[Path] = [],
        installed_packages: set[str] = set();

    def read_source_lines(file_path: str, line: int, context_lines: int = 2) -> str;
}

"""Collection of diagnostics."""
class DiagnosticCollection {
    has items: list[Diagnostic] = [];

    def add(self: DiagnosticCollection, diagnostic: Diagnostic) -> None;
    def add_all(self: DiagnosticCollection, diagnostics: list[Diagnostic]) -> None;
}

"""Base class for all diagnostic detectors."""
class BaseDetector {
    has code: str = "JAC_CLIENT_000",
        title: str = "Unknown Error",
        priority: int = 100,
        patterns: list[str] = [];

    def handle(self: BaseDetector, error: str) -> bool;
    def detect(self: BaseDetector, ctx: BuildContext) -> list[Diagnostic];
    def create_diagnostic(
        self: BaseDetector,
        message: str,
        severity: Severity = Severity.ERROR,
        file_path: str = "",
        line: int = 0,
        hint: str = "",
        quick_fix: str = ""
    ) -> Diagnostic;

    def extract_between(
        self: BaseDetector, text: str, start_delim: str, end_delim: str = ""
    ) -> str;

    def find_importing_file(
        self: BaseDetector, module_name: str, ctx: BuildContext
    ) -> tuple[str, int];
}

"""Detects missing npm dependencies."""
class MissingDependencyDetector(BaseDetector) {
    has code: str = "JAC_CLIENT_001",
        title: str = "Missing Dependency",
        priority: int = 10,
        patterns: list[str] = [
            "failed to resolve import",
            "cannot find module",
            "module not found",
            "can't resolve"
        ];

    def detect(self: MissingDependencyDetector, ctx: BuildContext) -> list[Diagnostic];
}

"""Detects syntax errors."""
class SyntaxErrorDetector(BaseDetector) {
    has code: str = "JAC_CLIENT_003",
        title: str = "Syntax Error",
        priority: int = 20,
        patterns: list[str] = [
            "syntaxerror",
            "unexpected token",
            "parsing error",
            "unterminated string"
        ];

    def detect(self: SyntaxErrorDetector, ctx: BuildContext) -> list[Diagnostic];
}

"""Detects Jac compilation/transpilation errors."""
class CompilationErrorDetector(BaseDetector) {
    has code: str = "JAC_CLIENT_005",
        title: str = "Compilation Error",
        priority: int = 1,
        patterns: list[str] = [
            "no bytecode found",
            "jacsyntaxerror",
            "jac syntax error",
            "compilation failed",
            "failed to compile"
        ];

    def detect(self: CompilationErrorDetector, ctx: BuildContext) -> list[Diagnostic];
}

"""Detects import path not found."""
class ImportNotFoundDetector(BaseDetector) {
    has code: str = "JAC_CLIENT_004",
        title: str = "Import Not Found",
        priority: int = 15,
        patterns: list[str] = ["failed to resolve import", "cannot find module"];

    def detect(self: ImportNotFoundDetector, ctx: BuildContext) -> list[Diagnostic];
}

"""Main engine for running diagnostic detectors."""
class DiagnosticEngine {
    has detectors: list[BaseDetector] = [];

    def register_all(self: DiagnosticEngine, detectors: list[BaseDetector]) -> None;
    def analyze(self: DiagnosticEngine, ctx: BuildContext) -> DiagnosticCollection;
}

"""Formats diagnostics for console output."""
class DiagnosticFormatter {
    has width: int = WIDTH;

    def format_diagnostic(self: DiagnosticFormatter, diag: Diagnostic) -> str;
    def format_collection(
        self: DiagnosticFormatter, collection: DiagnosticCollection
    ) -> str;

    def _pad(self: DiagnosticFormatter, content: str) -> str;
    def _wrap(self: DiagnosticFormatter, text: str, max_w: int) -> list[str];
}

"""Format a build error using the diagnostic system."""
def format_build_error(
    error_output: str,
    project_dir: Path,
    source_map: dict[str, str] = {},
    config: object = None
) -> str;

"""Check if debug mode is enabled."""
def is_debug_mode(config: object = None) -> bool;

"""Get all built-in detectors."""
def get_default_detectors -> list[BaseDetector];
