"""Various analysis helper types and functions."""

from pathlib import Path
from typing import TextIO

from jaclang.compiler.passes.main import BinderPass
from jaclang.compiler.program import JacProgram

from .diagnostic import Diagnostic


class JacTypeAnalyzer:
    """Jac Type Analyzer."""

    def __init__(self) -> None:
        """Initialize the JacTypeAnalyzer."""
        self.diagnostics: dict[Path, list[Diagnostic]] = {}

        # This is a temporary set to track files that have been bound and will be skipped
        # to ensure the file needed to bind. The VSCode extension will need to account for this.
        self.binded_files: set[Path] = set()

    # PyrightReference: packages/pyright-internal/src/analyzer/analysis.ts:analyzeProgram
    def analyze_program(self, program: JacProgram) -> None:
        """Run analysis on the module and report diagnostics."""
        # Pyright will call in this order program.analyze() > ._checkTypes() > ._bindFile()
        # we're skipping the intermediate calls and directly invoking the binder pass.
        for file_path_str, mod in program.mod.hub.items():
            file_path = Path(file_path_str).resolve()

            if self._should_skip_file(file_path):
                continue

            binder = BinderPass(ir_in=mod, prog=program)
            self.binded_files.add(file_path)

            # Since the file is (re)binded, all the previous diagnostics are invalidated.
            self._clear_diagnostics(file_path)
            for diag in binder.diagnostics:
                self._add_diagnostic(file_path, diag)

    def dump_diagnostics(self, file: TextIO) -> None:
        """Dump all diagnostics to the specified file."""
        for file_path, diags in self.diagnostics.items():
            if not diags:
                continue
            print(f"Diagnostics for {file_path}:", file=file)
            for diag in diags:
                print(
                    "  Diagnostic(\n"
                    f"    rule={diag.rule.name},\n"
                    f"    message='{diag.message}',\n"
                    f"    codeloc='{diag.codeloc}',\n"
                    "  )",
                    file=file,
                )

    # -------------------------------------------------------------------------
    # Internal private methods
    # -------------------------------------------------------------------------

    def _should_skip_file(self, file_path: Path) -> bool:
        """Check if the file should be skipped from analyzing."""
        return file_path in self.binded_files

    def _clear_diagnostics(self, file_path: Path) -> None:
        """Clear all diagnostics for the given file."""
        self.diagnostics.pop(file_path, None)

    def _add_diagnostic(self, file_path: Path, diag: Diagnostic) -> None:
        """Add a diagnostic for the given file."""
        self.diagnostics.setdefault(file_path, []).append(diag)
