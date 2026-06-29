def separator(text: str, char: str = '=', total_width: int = 80) -> str;

def print_file_progress(file_path: str, success: bool, idx: int, total: int) -> None;

def print_failures(failed_results: list, nowarn: bool = False) -> None;

def print_failed_summary(failed_results: list) -> None;

def print_final_summary(passed_count: int, failed_count: int, elapsed: float) -> None;
