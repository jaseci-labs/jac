"""Error reporting utilities for jac-client bundling errors.

Provides structured error parsing and formatting for Babel and Vite bundling errors,
with source mapping back to original .jac files.
"""

import re;
import from pathlib { Path }

"""Structured representation of a bundling error."""
obj BundleError {
    has error_type: str,  # Error category (e.g., "DuplicateImport", "SyntaxError")
        message: str,  # Error message
        file_path: (str | None),  # File where error occurred
        line: (int | None),  # Line number
        column: (int | None),  # Column number
        identifier: (str | None),  # Related identifier (e.g., duplicate import name)
        code_context: (str | None),  # Code snippet showing error location
        suggestion: (str | None);  # Actionable fix suggestion
}

"""Parser and formatter for Babel/Vite bundling errors."""
obj BundleErrorReporter {
    has project_dir: Path;

    def parse_error(raw_error: str) -> BundleError;
    def format_error(error: BundleError) -> str;
    def report_error(raw_error: str) -> str;
    def _resolve_jac_source(compiled_path: str) -> (str | None);
    def _classify_error(raw_error: str) -> str;
    def _get_suggestion(error_type: str, identifier: (str | None)) -> (str | None);
    def _extract_identifier(raw_error: str, error_type: str) -> (str | None);
    def _extract_code_context(raw_error: str) -> (str | None);
    def _extract_file_info(raw_error: str) -> tuple;
    def _extract_message(raw_error: str) -> str;
}
