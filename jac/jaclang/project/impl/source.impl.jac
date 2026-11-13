impl pascal_to_snake(pascal_string: str) -> str {
    snake_string = '';
    for (idx, ch) in enumerate(pascal_string) {
        if (idx > 0) and (ch >= 'A') and (ch <= 'Z') {
            snake_string += '_';
        }
        snake_string += ch;
    }
    return snake_string.lower();
}

impl add_line_numbers(s: str) -> str {
    lines = s.split('\n');
    return '\n'.join([f"{(i + 1)}:       {line}" for (i, line) in enumerate(lines)]);
}

impl pretty_print_source_location(
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

impl pretty_print_span(span: Span, *, colors: bool = False) -> str {
    return pretty_print_source_location(
        span.mod_path,
        span.src_window,
        span.first_line,
        span.pos_start - span.window_offset,
        span.pos_end - span.window_offset,
        colors=colors
    );
}

impl format_related_spans(
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

impl render_diagnostic_header(
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

impl render_diagnostic(
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

impl _to_posix_path(raw_path: str) -> str {
    return raw_path.replace(os.sep, '/');
}

impl path_matches_exclude(
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

impl normalize_exclude_patterns(patterns: list[str]) -> list[str] {
    normalized: list[str] = [];
    for raw in (patterns or []) {
        stripped = raw.strip();
        if stripped and not stripped.startswith('#') {
            normalized.append(stripped.rstrip('/'));
        }
    }
    return normalized;
}

impl is_secret_file(name: str) -> bool {
    return name == ".env"
        or name.startswith(".env.")
        or name in SECRET_FILE_NAMES
        or name.endswith(SECRET_FILE_SUFFIXES);
}
