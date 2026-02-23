"""Formatting utilities for jac check output (pytest-style)."""

"""Returns a separator line with centered text."""
def separator(text: str, char: str = '=', total_width: int = 80) -> str;

"""Prints a pytest-style progress line for a file check."""
def print_file_progress(file_path: str, success: bool, idx: int, total: int) -> None;

"""Prints the FAILURES section with errors and warnings for each failed file."""
def print_failures(failed_results: list, nowarn: bool = False) -> None;

"""Prints a summary of failed files with their error and warning counts."""
def print_failed_summary(failed_results: list) -> None;

"""Prints the final passed/failed counts with elapsed time."""
def print_final_summary(passed_count: int, failed_count: int, elapsed: float) -> None;
