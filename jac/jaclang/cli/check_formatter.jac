"""Formatting utilities for jac check output (pytest-style).

This module provides reusable formatting functions for displaying
check results in a clean, pytest-inspired format.
"""

"""Create a separator line with centered text.

Args:
    text: Text to center in the separator
    char: Character to use for the separator line (default: '=')
    total_width: Total width of the separator line (default: 80)

Returns:
    Formatted separator string
"""
def separator(text: str, char: str = '=', total_width: int = 80) -> str {
    text_part = f" {text} ";
    remaining = total_width - len(text_part);
    left_padding = remaining // 2;
    return char * left_padding + text_part + char * (remaining - left_padding);
}

"""Print file check progress line (pytest-style).

Args:
    file_path: Path to the file being checked
    success: Whether the check passed
    idx: Current file index (1-based)
    total: Total number of files to check
"""
def print_file_progress(file_path: str, success: bool, idx: int, total: int) -> None {
    import from jaclang.cli.console { console }
    percentage = int((idx / total) * 100);
    status = "PASSED" if success else "FAILED";
    console.print(f"{file_path} {status} [{percentage}%]");
}

"""Print detailed failures section.

Args:
    failed_results: List of failed file results
    nowarn: Whether to suppress warnings
"""
def print_failures(failed_results: list, nowarn: bool = False) -> None {
    import from jaclang.cli.console { console }
    console.print("");
    console.print(separator("FAILURES"));
    for r in failed_results {
        console.print(separator(r['path'], char='_'));
        for e in r['errors'] {
            console.error(f"{e}");
        }
        if not nowarn and r['warnings'] {
            for w in r['warnings'] {
                console.warning(f"{w}");
            }
        }
        console.print("");
    }
}

"""Print failed files summary.

Args:
    failed_results: List of failed file results
"""
def print_failed_summary(failed_results: list) -> None {
    import from jaclang.cli.console { console }
    console.print(separator("failed files"));
    for r in failed_results {
        err_s = '' if r['error_count'] == 1 else 's';
        warn_s = '' if r['warning_count'] == 1 else 's';
        console.print(f"{r['path']} - {r['error_count']} error{err_s}, {r['warning_count']} warning{warn_s}");
    }
}

"""Print final summary line with timing.

Args:
    passed_count: Number of files that passed
    failed_count: Number of files that failed
    elapsed: Elapsed time in seconds
"""
def print_final_summary(passed_count: int, failed_count: int, elapsed: float) -> None {
    import from jaclang.cli.console { console }
    parts = [f"{passed_count} passed"] if passed_count > 0 else [];
    if failed_count > 0 {
        parts.append(f"{failed_count} failed");
    }
    console.print(separator(", ".join(parts) + f" in {elapsed:.2f}s"));
}
