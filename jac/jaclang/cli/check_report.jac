def separator(text: str, char: str = '=', total_width: int = 80) -> str;

def print_file_progress(file_path: str, success: bool, idx: int, total: int) -> None;

def print_failures(failed_results: list[dict[str, any]], nowarn: bool = False) -> None;

def print_failed_summary(failed_results: list[dict[str, any]]) -> None;

def print_final_summary(passed_count: int, failed_count: int, elapsed: float) -> None;

def print_native_coverage(coverage: dict[str, dict[str, any]]) -> None;

def print_placement_report(rows_by_module: dict[str, dict[str, any]]) -> None;
