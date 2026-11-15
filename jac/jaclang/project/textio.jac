import os;

glob _JAC_TEXT_ENCODINGS: list[str] = [
         'utf-8-sig',
         'utf-8',
         'utf-16',
         'utf-16le',
         'utf-16be'
     ];

def read_file_with_encoding(file_path: str) -> str;

def read_jacignore_patterns(project_root: str) -> list[str];

def span_for_file(
    mod_path: str, line: int, col: int, end_col: int = 0, source: str = ''
) -> Span;

def drop_git_ignored(paths: list[str], cwd: str = "") -> list[str];
