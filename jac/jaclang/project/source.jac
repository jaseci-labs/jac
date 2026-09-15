import os;
import from contextvars { ContextVar }
import type from jaclang.compiler.frontend.srcloc { Span }

obj SourceAccess {
    has read: Callable[[str], str],
        annexes: Callable[[str], list[tuple[str, str]]] | None = None,
        exists: Callable[[str], bool] | None = None,
        read_bytes: Callable[[str], bytes] | None = None;
}

glob source_access: ContextVar[SourceAccess | None] = ContextVar(
         'jac_source_access', `default=None
     );

def disk_annex_paths(path: str) -> list[str] {
    import from jaclang.compiler.driver.bccache {
        discover_annex_files,
        discover_base_file
    }
    if not path.endswith('.jac') or discover_base_file(path) is not None {
        return [];
    }
    return sorted(
        set(discover_annex_files(path, '.impl.jac'))
            | set(discover_annex_files(path, '.test.jac'))
    );
}

def read_source_unit(path: str) -> tuple[str, list[tuple[str, str]]] {
    access = source_access.get();
    annexes = access.annexes(path)
        if access is not None and access.annexes is not None
        else [
            (read_file_with_encoding(annex), annex) for annex in disk_annex_paths(path)
        ];
    return (read_file_with_encoding(path), annexes);
}

def iter_source_units(directory: str) -> Iterator[str] {
    import from jaclang.jac0core.ext_registry { is_annex }
    patterns = read_jacignore_patterns(directory);
    excluded = {'__pycache__', 'venv', 'node_modules', 'build', 'dist'};
    for (parent, directories, files) in os.walk(os.path.realpath(directory)) {
        directories[:] = sorted(
            name
            for name in directories
            if not name.startswith('.') and name not in excluded
                and not path_matches_exclude(os.path.join(parent, name), patterns, directory)
        );
        for name in sorted(files) {
            if name.endswith('.jac') and not is_annex(name)
                and not path_matches_exclude(os.path.join(parent, name), patterns, directory) {
                yield os.path.realpath(os.path.join(parent, name));
            }
        }
    }
}

def pascal_to_snake(pascal_string: str) -> str {
    snake_string = '';
    for (idx, ch) in enumerate(pascal_string) {
        if (idx > 0) and (ch >= 'A') and (ch <= 'Z') {
            snake_string += '_';
        }
        snake_string += ch;
    }
    return snake_string.lower();
}

def add_line_numbers(s: str) -> str {
    lines = s.split('\n');
    return '\n'.join(f"{(i + 1)}:       {line}" for (i, line) in enumerate(lines));
}

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
) -> str {
    line_num_width: int = 5;
    if ((file_source == '') or (file_path == '')) {
        return '';
    }

    fb = file_source.encode("utf-8");
    flen: int = len(fb);
    NL: int = 10;
    idx: int = pos_start;
    if (idx > flen) {
        idx = flen;
    }
    start_line: int = error_line - 2;
    if (start_line < 1) {
        start_line = 1;
    }
    end_line: int = start_line + 5;
    curr_line: int = error_line;
    while ((idx >= 0) and (curr_line >= start_line)) {
        idx -= 1;
        if (idx < 0) {
            break;
        }
        if (fb[idx] == NL) {
            curr_line -= 1;
        }
    }
    idx += 1;
    pretty_dump = '';
    curr_line = start_line;
    while (curr_line < end_line) {
        gutter: str = str(curr_line);
        while (len(gutter) < line_num_width) {
            gutter = ' ' + gutter;
        }
        pretty_dump += gutter + " | ";
        idx_line_start = idx;
        while ((idx < flen) and (fb[idx] != NL)) {
            idx += 1;
        }
        if (colors and (curr_line == error_line)) {
            pre = fb[idx_line_start:pos_start].decode("utf-8", errors="replace");
            mid = fb[pos_start:pos_end].decode("utf-8", errors="replace");
            post = fb[pos_end:idx].decode("utf-8", errors="replace");
            pretty_dump += pre + f"{ANSIColors.RED}{mid}{ANSIColors.END}" + post;
        } else {
            pretty_dump += fb[idx_line_start:idx].decode("utf-8", errors="replace");
        }
        pretty_dump += '\n';
        if (curr_line == error_line) {
            blank_gutter: str = ' ';
            while (len(blank_gutter) < line_num_width) {
                blank_gutter = ' ' + blank_gutter;
            }
            pretty_dump += blank_gutter + " | ";

            prefix = fb[idx_line_start:pos_start].decode("utf-8", errors="replace");
            spaces = '';
            for ch in prefix {
                spaces += '\t' if (ch == '\t') else ' ';
            }
            err_token_len = len(
                fb[pos_start:pos_end].decode("utf-8", errors="replace")
            );
            line_remaining = len(fb[pos_start:idx].decode("utf-8", errors="replace"));
            if (line_remaining > 0 and err_token_len > line_remaining) {
                err_token_len = line_remaining;
            }
            if (err_token_len < 1) {
                err_token_len = 1;
            }
            underline: str = '^' * err_token_len;
            if colors {
                underline = f"{ANSIColors.RED}{underline}{ANSIColors.END}";
            }
            pretty_dump += spaces + underline + '\n';
        }
        if (idx == flen) {
            break;
        }
        curr_line += 1;
        idx += 1;
    }
    return pretty_dump[:-1];
}

def pretty_print_span(span: Span, *, colors: bool = False) -> str {
    return pretty_print_source_location(
        span.mod_path,
        span.src_window,
        span.first_line,
        span.pos_start - span.window_offset,
        span.pos_end - span.window_offset,
        colors=colors
    );
}

def format_related_spans(
    related: list[tuple[str, Span]], *, colors: bool = False
) -> str {
    result = '';
    for (label, span) in related {
        mod_path = span.mod_path;
        first_line = span.first_line;
        col_start = span.col_start;
        if colors {
            result += f"\n{ANSIColors.CYAN}note{ANSIColors.END}: {label}";
        } else {
            result += f"\nnote: {label}";
        }
        if (mod_path != '') {
            result += f"\n  --> {mod_path}:{first_line}:{col_start}";
            span_dump = pretty_print_span(span, colors=colors);
            if (span_dump != '') {
                result += '\n' + span_dump;
            }
        }
    }
    return result;
}

def span_for_file(
    mod_path: str, line: int, col: int, end_col: int = 0, source: str = ''
) -> Span {
    import from jaclang.compiler.frontend.srcloc { Span }
    bare = Span(
        mod_path=mod_path,
        first_line=line,
        last_line=line,
        col_start=col,
        col_end=(end_col if end_col > col else col)
    );
    if (line < 1) or (mod_path == '') {
        return bare;
    }
    code = source;
    if (code == '') {
        try {
            code = read_file_with_encoding(mod_path);
        } except Exception {
            return bare;
        }
    }
    fb = code.encode("utf-8");
    flen = len(fb);
    off = 0;
    curr = 1;
    while (curr < line) {
        nl = fb.find(b'\n', off);
        if (nl < 0) {
            return bare;
        }
        off = nl + 1;
        curr += 1;
    }
    start = off + (col - 1 if col > 0 else 0);
    if (start > flen) {
        start = flen;
    }
    stop = off + (end_col - 1) if (end_col > col) else (start + 1);
    if (stop > flen) {
        stop = flen;
    }
    return Span.make(
        mod_path,
        code,
        (line, line),
        (col, end_col if (end_col > col) else col),
        (start, stop)
    );
}

def render_diagnostic_header(
    message: str,
    code: str = '',
    severity: str = 'error',
    loc: (Span | None) = None,
    *,
    colors: bool = False
) -> str {
    file_path = loc.mod_path if (loc is not None) else '';
    if (code != '') {
        if colors {
            color = ANSIColors.RED if (severity == 'error') else ANSIColors.YELLOW;
            header = f"{color}{severity}[{code}]{ANSIColors.END}: {message}";
        } else {
            header = f"{severity}[{code}]: {message}";
        }
        if (file_path == '') or (loc is None) {
            return header;
        }
        return f"{header}\n  --> {file_path}:{loc.first_line}:{loc.col_start}";
    }
    if (file_path == '') or (loc is None) {
        return message;
    }
    body = message if not colors else f"{ANSIColors.RED}{message}{ANSIColors.END}";
    return f"{file_path}:{loc.first_line}:{loc.col_start} {body}";
}

def render_diagnostic(
    message: str,
    code: str = '',
    severity: str = 'error',
    loc: (Span | None) = None,
    related: (list[tuple[str, Span]] | None) = None,
    help_text: (str | None) = None,
    *,
    colors: bool = False
) -> str {
    result = render_diagnostic_header(message, code, severity, loc, colors=colors);
    if (loc is not None) {
        span_dump = pretty_print_span(loc, colors=colors);
        if (span_dump != '') {
            result += '\n' + span_dump;
        }
    }
    if related {
        result += format_related_spans(related, colors=colors);
    }
    if help_text {
        if colors {
            result += f"\n{ANSIColors.CYAN}help{ANSIColors.END}: {help_text}";
        } else {
            result += f"\nhelp: {help_text}";
        }
    }
    return result;
}

glob _JAC_TEXT_ENCODINGS = [
         'utf-8-sig',
         'utf-8',
         'utf-16',
         'utf-16le',
         'utf-16be'
     ];

def decode_source(data: bytes, file_path: str = '') -> str {
    for encoding in _JAC_TEXT_ENCODINGS {
        try {
            return data.decode(encoding).replace('\r\n', '\n').replace('\r', '\n');
        } except UnicodeError {
            continue;
        }
    }
    raise OSError(
        f"Could not read file {file_path} with any encoding. Report this issue:https://github.com/jaseci-labs/jaseci/issues"
    );
}


def read_file_bytes(file_path: str) -> bytes {
    access = source_access.get();
    if access is not None {
        if access.read_bytes is not None {
            return access.read_bytes(file_path);
        }
        return access.read(file_path).encode('utf-8');
    }
    with open(file_path, 'rb') as source {
        return source.read();
    }
}

def read_file_with_encoding(file_path: str) -> str {
    access = source_access.get();
    if access is not None {
        return access.read(file_path);
    }
    return decode_source(read_file_bytes(file_path), file_path);
}

def source_exists(file_path: str) -> bool {
    access = source_access.get();
    if access is None {
        return os.path.isfile(file_path);
    }
    if access.exists is not None {
        return access.exists(file_path);
    }
    try {
        access.read(file_path);
        return True;
    } except OSError {
        return False;
    }
}

def _to_posix_path(raw_path: str) -> str {
    return raw_path.replace(os.sep, '/');
}


def path_matches_exclude(
    file_path: str, patterns: list[str], project_root: str = ""
) -> bool {
    import from fnmatch { fnmatch }
    if not patterns {
        return False;
    }
    norm = _to_posix_path(file_path);
    if project_root {
        root_prefix = _to_posix_path(project_root).rstrip('/') + '/';
        if norm.startswith(root_prefix) {
            norm = norm[len(root_prefix):];
        }
    }
    parts = [
        p
        for p in norm.split('/')
        if p
    ];
    for pattern in patterns {
        if '/' in pattern {
            if fnmatch(norm, pattern)
                or fnmatch(norm, '*/' + pattern)
                or fnmatch('_/' + norm, pattern) {
                return True;
            }
        } else {
            for part in parts {
                if fnmatch(part, pattern) {
                    return True;
                }
            }
        }
    }
    return False;
}


glob JACIGNORE_FILENAME: str = '.jacignore';


def normalize_exclude_patterns(patterns: list[str]) -> list[str] {
    normalized: list[str] = [];
    for raw in (patterns or []) {
        stripped = raw.strip();
        if stripped and not stripped.startswith('#') {
            normalized.append(stripped.rstrip('/'));
        }
    }
    return normalized;
}


def read_jacignore_patterns(project_root: str) -> list[str] {
    ignore_file = os.path.join(project_root, JACIGNORE_FILENAME);
    if not source_exists(ignore_file) {
        return [];
    }
    return normalize_exclude_patterns(
        read_file_with_encoding(ignore_file).splitlines()
    );
}
