import os;

def pascal_to_snake(pascal_string: str) -> str;

def add_line_numbers(s: str) -> str;

class ANSIColors {
    with entry {
        BLACK = '\x1b[0;30m';
        RED = '\x1b[0;31m';
        GREEN = '\x1b[0;32m';
        BROWN = '\x1b[0;33m';
        BLUE = '\x1b[0;34m';
        PURPLE = '\x1b[0;35m';
        CYAN = '\x1b[0;36m';
        LIGHT_GRAY = '\x1b[0;37m';
        DARK_GRAY = '\x1b[1;30m';
        LIGHT_RED = '\x1b[1;31m';
        LIGHT_GREEN = '\x1b[1;32m';
        YELLOW = '\x1b[1;33m';
        LIGHT_BLUE = '\x1b[1;34m';
        LIGHT_PURPLE = '\x1b[1;35m';
        LIGHT_CYAN = '\x1b[1;36m';
        LIGHT_WHITE = '\x1b[1;37m';
        BOLD = '\x1b[1m';
        FAINT = '\x1b[2m';
        ITALIC = '\x1b[3m';
        UNDERLINE = '\x1b[4m';
        BLINK = '\x1b[5m';
        NEGATIVE = '\x1b[7m';
        CROSSED = '\x1b[9m';
        END = '\x1b[0m';
    }
}

def pretty_print_source_location(
    file_path: str,
    file_source: str,
    error_line: int,
    pos_start: int,
    pos_end: int,
    *,
    colors: bool = False
) -> str;

def pretty_print_span(span: Span, *, colors: bool = False) -> str;

def format_related_spans(
    related: list[tuple[str, Span]], *, colors: bool = False
) -> str;

def render_diagnostic_header(
    message: str,
    code: str = '',
    severity: str = 'error',
    loc: (Span | None) = None,
    *,
    colors: bool = False
) -> str;

def render_diagnostic(
    message: str,
    code: str = '',
    severity: str = 'error',
    loc: (Span | None) = None,
    related: (list[tuple[str, Span]] | None) = None,
    help_text: (str | None) = None,
    *,
    colors: bool = False
) -> str;

def _to_posix_path(raw_path: str) -> str;


def path_matches_exclude(
    file_path: str, patterns: list[str], project_root: str = ""
) -> bool;


glob JACIGNORE_FILENAME: str = '.jacignore';


def normalize_exclude_patterns(patterns: list[str]) -> list[str];
