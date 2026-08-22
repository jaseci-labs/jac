import os;
import type from jaclang.jac0core.srcloc { CodeLocInfo }
import type from jaclang.jac0core.unitree { Expr }

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

def format_related_spans(
    related: list[tuple[str, CodeLocInfo]], *, colors: bool = False
) -> str {
    result = '';
    for (label, loc) in related {
        mod_path = loc.mod_path;
        first_line = loc.first_line;
        col_start = loc.col_start;
        if colors {
            result += f"\n{ANSIColors.CYAN}note{ANSIColors.END}: {label}";
        } else {
            result += f"\nnote: {label}";
        }
        if (mod_path != '') {
            result += f"\n  --> {mod_path}:{first_line}:{col_start}";
            try {
                source = loc.orig_src.code;
                span_dump = pretty_print_source_location(
                    mod_path,
                    source,
                    first_line,
                    loc.pos_start,
                    loc.pos_end,
                    colors=colors
                );
                if (span_dump != '') {
                    result += '\n' + span_dump;
                }
            } except Exception {
                ;
            }
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

def read_file_with_encoding(file_path: str) -> str {
    for encoding in _JAC_TEXT_ENCODINGS {
        try {
            with open(file_path, encoding=encoding) as f {
                return f.read();
            }
        } except UnicodeError {
            continue;
        } except Exception as e {
            raise OSError(
                f"Could not read file {file_path}: {e}. Report this issue: https://github.com/jaseci-labs/jaseci/issues"
            );
        }
    }
    raise OSError(
        f"Could not read file {file_path} with any encoding. Report this issue:https://github.com/jaseci-labs/jaseci/issues"
    );
}


def path_matches_exclude(
    file_path: str, patterns: list[str], project_root: str = ""
) -> bool {
    import from fnmatch { fnmatch }
    if not patterns {
        return False;
    }
    norm: str = file_path.replace(os.sep, '/');
    if project_root {
        root_prefix = project_root.replace(os.sep, '/').rstrip('/') + '/';
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


def normalize_exclude_patterns(patterns: list) -> list[str] {
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
    if not os.path.isfile(ignore_file) {
        return [];
    }
    return normalize_exclude_patterns(
        read_file_with_encoding(ignore_file).splitlines()
    );
}


def _is_version_info_access(expr: Expr) -> bool {
    import jaclang.jac0core.unitree as uni;

    if not isinstance(expr, uni.AtomTrailer) {
        return False;
    }
    if not expr.is_attr {
        return False;
    }
    return (
        isinstance(expr.target, uni.Name)
        and expr.target.value == "sys"
        and isinstance(expr.right, uni.Name)
        and expr.right.value == "version_info"
    );
}

def _is_type_checking_ref(expr: Expr) -> bool {
    import jaclang.jac0core.unitree as uni;

    inner = expr;
    if isinstance(expr, uni.AtomUnit) {
        unwrapped = expr.value;
        if not isinstance(unwrapped, uni.Expr) {
            return False;
        }
        inner = unwrapped;
    }
    if isinstance(inner, uni.Name) {
        return inner.value == "TYPE_CHECKING";
    }
    if isinstance(inner, uni.AtomTrailer) and inner.is_attr {
        return (
            isinstance(inner.right, uni.Name) and inner.right.value == "TYPE_CHECKING"
        );
    }
    return False;
}

def _extract_version_tuple(expr: Expr) -> tuple[int, int] | None {
    import jaclang.jac0core.unitree as uni;

    if not isinstance(expr, uni.TupleVal) {
        return None;
    }
    if len(expr.values) < 2 {
        return None;
    }
    (major, minor) = (expr.values[0], expr.values[1]);
    if not isinstance(major, uni.Int) or not isinstance(minor, uni.Int) {
        return None;
    }
    return (major.lit_value, minor.lit_value);
}

def evaluate_version_condition(condition: Expr) -> bool | None {
    import sys;
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.constant { Tokens as Tok }

    cond = condition;
    if isinstance(condition, uni.AtomUnit) {
        unwrapped = condition.value;
        if not isinstance(unwrapped, uni.Expr) {
            return None;
        }
        cond = unwrapped;
    }

    if _is_type_checking_ref(cond) {
        return True;
    }
    if isinstance(cond, uni.UnaryExpr)
        and cond.op.name == Tok.NOT
        and _is_type_checking_ref(cond.operand) {
        return False;
    }
    if not isinstance(cond, uni.CompareExpr) {
        return None;
    }
    if not _is_version_info_access(cond.left) {
        return None;
    }
    if len(cond.ops) != 1 or len(cond.rights) != 1 {
        return None;
    }

    target = _extract_version_tuple(cond.rights[0]);
    if target is None {
        return None;
    }

    current = (sys.version_info.major, sys.version_info.minor);
    op_str = cond.ops[0].value;
    if op_str in (">=", "GtE") {
        return current >= target;
    }
    if op_str in (">", "Gt") {
        return current > target;
    }
    if op_str in ("<=", "LtE") {
        return current <= target;
    }
    if op_str in ("<", "Lt") {
        return current < target;
    }
    if op_str in ("==", "Eq") {
        return current == target;
    }
    if op_str in ("!=", "NotEq") {
        return current != target;
    }
    return None;
}
