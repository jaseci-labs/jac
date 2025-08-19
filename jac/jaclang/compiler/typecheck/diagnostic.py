"""Diagnostic class definition."""

from dataclasses import dataclass

from jaclang.compiler.codeinfo import CodeLocInfo

from .diagnostic_rules import DiagnosticRule


@dataclass
class Diagnostic:
    """A diagnostics class representing a specific diagnostic issue."""

    rule: DiagnosticRule
    codeloc: CodeLocInfo

    # TODO: The descriptive message for the diagnostics are found at:
    # packages\pyright-internal\src\localization\package.nls.en-us.json
    # different json file for each localization.
    message: str = ""
