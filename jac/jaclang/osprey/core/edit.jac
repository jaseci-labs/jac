def apply_edit(source: str, old_text: str, new_text: str) -> str;

def apply_multi_edit(source: str, edits: list[list[str]]) -> str;

def replace_lines(
    source: str, start_line: int, end_line: int, replacement: str
) -> str;

def count_matches(source: str, needle: str) -> int;

def compute_unified_diff(old_text: str, new_text: str, context: int = 3) -> str;

def _fmt_range(start: int, length: int) -> str;

def guess_indentation(source: str) -> str;
