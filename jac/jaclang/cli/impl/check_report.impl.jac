"""Impl of Formatting utilities for jac check output"""

impl separator(text: str, char: str = '=', total_width: int = 80) -> str {
    text_part = f" {text} ";
    remaining = total_width - len(text_part);
    left_padding = remaining // 2;
    return char * left_padding + text_part + char * (remaining - left_padding);
}

impl print_file_progress(file_path: str, success: bool, idx: int, total: int) -> None {
    import from jaclang.cli.console { console }
    percentage = int((idx / total) * 100);
    status = "PASSED" if success else "FAILED";
    console.print(f"{file_path} {status} [{percentage}%]");
}

impl print_failures(failed_results: list, nowarn: bool = False) -> None {
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

impl print_failed_summary(failed_results: list) -> None {
    import from jaclang.cli.console { console }
    console.print(separator("failed files"));
    for r in failed_results {
        err_count = len(r['errors']);
        warn_count = len(r['warnings']);
        err_s = '' if err_count == 1 else 's';
        warn_s = '' if warn_count == 1 else 's';
        console.print(
            f"{r['path']} - {err_count} error{err_s}, {warn_count} warning{warn_s}"
        );
    }
}

impl print_final_summary(passed_count: int, failed_count: int, elapsed: float) -> None {
    import from jaclang.cli.console { console }
    parts = [f"{passed_count} passed"] if passed_count > 0 else [];
    if failed_count > 0 {
        parts.append(f"{failed_count} failed");
    }
    console.print(separator(", ".join(parts) + f" in {elapsed:.2f}s"));
}
