import os;
import sys;
import from contextlib { contextmanager }

glob RESET: str = "\033[0m",
     BOLD: str = "\033[1m",
     DIM: str = "\033[2m",
     UNDERLINE: str = "\033[4m",
     RED: str = "\033[31m",
     GREEN: str = "\033[32m",
     YELLOW: str = "\033[33m",
     BLUE: str = "\033[34m",
     MAGENTA: str = "\033[35m",
     CYAN: str = "\033[36m",
     WHITE: str = "\033[37m",
     BRIGHT_WHITE: str = "\033[97m",
     BRIGHT_BLUE: str = "\033[94m";

glob _ANSI_ROLES: dict = {
         'success': GREEN,
         'error': RED,
         'warning': YELLOW,
         'info': CYAN,
         'muted': DIM,
         'highlight': CYAN,
         'url': BRIGHT_BLUE + UNDERLINE,
         'time': GREEN,
         'bright_white': BRIGHT_WHITE
     };

glob _ANSI_STYLE_TOKENS: dict = {
         'bold': BOLD,
         'dim': DIM,
         'underline': UNDERLINE,
         'red': RED,
         'green': GREEN,
         'yellow': YELLOW,
         'blue': BLUE,
         'magenta': MAGENTA,
         'cyan': CYAN,
         'white': WHITE,
         'bright_white': BRIGHT_WHITE,
         'bright_blue': BRIGHT_BLUE
     };


def _stream_is_tty(stream: any) -> bool {
    try {
        isatty = stream?.isatty;
        if isatty is None {
            return False;
        }
        return bool(isatty());
    } except Exception {
        return False;
    }
}

def _resolve_ansi_style(style: str | None) -> str {
    if not style {
        return "";
    }
    mapped = _ANSI_ROLES.get(style);
    if mapped {
        return str(mapped);
    }
    codes: list[str] = [];
    for token in style.split() {
        if token in _ANSI_STYLE_TOKENS {
            codes.append(str(_ANSI_STYLE_TOKENS[token]));
        }
    }
    return ''.join(codes);
}

glob _SPINNER_FRAMES: list[str] = [
         '⠋',
         '⠙',
         '⠹',
         '⠸',
         '⠼',
         '⠴',
         '⠦',
         '⠧',
         '⠇',
         '⠏'
     ],
     _SPINNER_FRAMES_ASCII: list[str] = ['|', '/', '-', "\\"];

glob _BOX_UNICODE: dict[str, str] = {
         'tl': '┌',
         'tm': '┬',
         'tr': '┐',
         'ml': '├',
         'mm': '┼',
         'mr': '┤',
         'bl': '└',
         'bm': '┴',
         'br': '┘',
         'h': '─',
         'v': '│',
         'ptl': '╭',
         'ptr': '╮',
         'pbl': '╰',
         'pbr': '╯'
     },
     _BOX_ASCII: dict[str, str] = {
         'tl': '+',
         'tm': '+',
         'tr': '+',
         'ml': '+',
         'mm': '+',
         'mr': '+',
         'bl': '+',
         'bm': '+',
         'br': '+',
         'h': '-',
         'v': '|',
         'ptl': '+',
         'ptr': '+',
         'pbl': '+',
         'pbr': '+'
     };

def _table_border(widths: list[int], left: str, mid: str, right: str, h: str) -> str {
    segs = [h * (w + 2) for w in widths];
    return left + mid.join(segs) + right;
}


def _make_spinner(use_color: bool, use_emoji: bool, text: str) -> any {
    if not use_color {
        return None;
    }
    try {
        if not sys.stdout.isatty() {
            return None;
        }
    } except Exception {
        return None;
    }
    frames = _SPINNER_FRAMES if use_emoji else _SPINNER_FRAMES_ASCII;
    prefix = str(_ANSI_ROLES.get('highlight') or "");
    return _Spinner(
        text=text, stream=sys.stdout, frames=frames, style_prefix=prefix, reset=RESET
    );
}

impl ConsoleRenderer.configure(use_emoji: bool, use_color: bool) -> None {
    self.use_emoji = use_emoji;
    self.use_color = use_color;
}


impl ConsoleRenderer.emit(spans: list[Span], stream: any = None) -> None {
    out = stream if stream is not None else sys.stdout;
    can_style = self.use_color and _stream_is_tty(out);
    parts: list[str] = [];
    for s in spans {
        if can_style and s.style is not None and _ANSI_ROLES.get(s.style) {
            parts.append(f"{_ANSI_ROLES.get(s.style)}{s.text}{RESET}");
        } else {
            parts.append(s.text);
        }
    }
    try {
        print(''.join(parts), file=out);
    } except (BrokenPipeError, OSError) {
        return;
    }
    try {
        out.flush();
    } except (BrokenPipeError, OSError) {
        ;
    }
}


impl ConsoleRenderer.emit_raw(
    args: list, stream: any, style: str | None, kwargs: dict
) -> None {
    out = stream if stream is not None else sys.stdout;
    can_style = self.use_color and _stream_is_tty(out);
    style_prefix = _resolve_ansi_style(style) if can_style else "";
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') {
        encoding: str = str(out?.encoding or 'cp1252');
        processed_args: list = [];
        for arg in args {
            if isinstance(arg, str) {
                try {
                    arg.encode(encoding);
                    processed_args.append(arg);
                } except UnicodeEncodeError {
                    processed_args.append(
                        arg.encode(encoding, errors='replace').decode(encoding)
                    );
                }
            } else {
                processed_args.append(arg);
            }
        }
        styled_args = (
            [
                f"{style_prefix}{arg}{RESET}" if isinstance(arg, str) else arg
                for arg in processed_args
            ]
                if style_prefix
                else processed_args
        );
        try {
            print(*styled_args, file=out, **kwargs);
        } except (BrokenPipeError, OSError) {
            return;
        }
    } else {
        styled_args = (
            [
                f"{style_prefix}{arg}{RESET}" if isinstance(arg, str) else arg
                for arg in args
            ]
                if style_prefix
                else args
        );
        try {
            print(*styled_args, file=out, **kwargs);
        } except (BrokenPipeError, OSError) {
            return;
        }
    }
    try {
        out.flush();
    } except (BrokenPipeError, OSError) {
        ;
    }
}

impl ConsoleRenderer.header(title: str, version: str | None = None) -> None {
    try {
        width = os.get_terminal_size().columns;
    } except (OSError, ValueError) {
        width = 80;
    }
    rule = '─' * width;
    if self.use_color {
        self.emit([Span(rule, 'muted')]);
        if version {
            self.emit(
                [
                    Span(title, 'bright_white'),
                    Span('  ', None),
                    Span(f"v{version}", 'muted')
                ]
            );
        } else {
            self.emit([Span(title, 'bright_white')]);
        }
        self.emit([Span(rule, 'muted')]);
    } else {
        self.emit([Span(rule, None)]);
        if version {
            self.emit([Span(f"{title} v{version}", None)]);
        } else {
            self.emit([Span(title, None)]);
        }
        self.emit([Span(rule, None)]);
    }
}

impl ConsoleRenderer.urls(items: list, symbol: str = '') -> None {
    sym = symbol or ('➜' if self.use_emoji else '>');
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        self.emit(
            [
                Span("  ", None),
                Span(sym, 'highlight'),
                Span("  ", None),
                Span(padded_label, 'muted'),
                Span(" ", None),
                Span(str(url), 'url')
            ]
        );
    }
}


impl ConsoleRenderer.next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    box = _BOX_UNICODE if self.use_emoji else _BOX_ASCII;
    rows: list[tuple[str, str]] = [];
    content_w = 0;
    for (i, step) in enumerate(steps, 1) {
        prefix = f"  {i}  ";
        content_w = max(content_w, len(prefix) + len(str(step)));
        rows.append((prefix, str(step)));
    }
    inner = max(content_w + 2, len(str(title)) + 4);
    self.emit([Span("", None)]);
    fill = inner - len(str(title)) - 3;
    top = box['ptl'] + box['h'] + " " + str(title) + " " + box['h'] * fill + box['ptr'];
    self.emit([Span(top, 'highlight')]);
    for (prefix, step) in rows {
        gap = (inner - 2) - (len(prefix) + len(step));
        self.emit(
            [
                Span(box['v'], 'highlight'),
                Span(" ", None),
                Span(prefix, 'highlight'),
                Span(step, None),
                Span(" " * gap, None),
                Span(" ", None),
                Span(box['v'], 'highlight')
            ]
        );
    }
    self.emit([Span(box['pbl'] + box['h'] * inner + box['pbr'], 'highlight')]);
    self.emit([Span("", None)]);
}


impl ConsoleRenderer.table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    box = _BOX_UNICODE if self.use_emoji else _BOX_ASCII;
    col_widths: list[int] = [len(str(h)) for h in headers];
    for row in rows {
        for (i, cell) in enumerate(row) {
            if i < len(col_widths) {
                col_widths[i] = max(col_widths[i], len(str(cell)));
            }
        }
    }
    if title {
        self.emit([Span(str(title), 'highlight')]);
    }
    self.emit(
        [
            Span(
                _table_border(col_widths, box['tl'], box['tm'], box['tr'], box['h']),
                'muted'
            )
        ]
    );
    header_spans: list[Span] = [Span(box['v'], 'muted')];
    for (h, w) in zip(headers, col_widths) {
        header_spans.append(Span(" ", None));
        header_spans.append(Span(str(h).ljust(w), 'highlight'));
        header_spans.append(Span(" ", None));
        header_spans.append(Span(box['v'], 'muted'));
    }
    self.emit(header_spans);
    self.emit(
        [
            Span(
                _table_border(col_widths, box['ml'], box['mm'], box['mr'], box['h']),
                'muted'
            )
        ]
    );
    for row in rows {
        row_spans: list[Span] = [Span(box['v'], 'muted')];
        for (i, w) in enumerate(col_widths) {
            cell = str(row[i]) if i < len(row) else "";
            row_spans.append(Span(" ", None));
            row_spans.append(Span(cell.ljust(w), None));
            row_spans.append(Span(" ", None));
            row_spans.append(Span(box['v'], 'muted'));
        }
        self.emit(row_spans);
    }
    self.emit(
        [
            Span(
                _table_border(col_widths, box['bl'], box['bm'], box['br'], box['h']),
                'muted'
            )
        ]
    );
}


@contextmanager
impl ConsoleRenderer.status_ctx(args: list, kwargs: dict) -> object {
    text = "";
    if args {
        text = args[0] if isinstance(args[0], str) else str(args[0]);
    }
    sp = _make_spinner(self.use_color, self.use_emoji, text);
    if sp is None {
        if text {
            self.emit([Span(text, 'muted')]);
        }
        yield _NullStatus();
    } else {
        sp.start();
        try {
            yield sp;
        } finally {
            sp.stop();
        }
    }
}

@contextmanager
impl ConsoleRenderer.spinner_ctx(text: str) -> object {
    with self.status_ctx([text], {}) as st {
        yield st;
    }
}


impl JacConsole.postinit -> None {
    self.use_emoji = JacConsole._should_use_emoji();
    self.use_color = JacConsole._should_use_color();
    self._renderer = self._make_renderer();
    self._renderer.configure(self.use_emoji, self.use_color);
}

impl JacConsole._make_renderer -> ConsoleRenderer {
    return ConsoleRenderer();
}

impl JacConsole._should_use_emoji -> bool {
    if os.environ.get('NO_EMOJI') or os.environ.get('TERM') == 'dumb' {
        return False;
    }
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') {
        return False;
    }
    return True;
}


impl JacConsole._should_use_color -> bool {
    if os.environ.get('NO_COLOR') {
        return False;
    }
    if os.environ.get('TERM') == 'dumb' {
        return False;
    }
    try {
        if not sys.stdout.isatty() {
            return False;
        }
    } except Exception {
        return False;
    }
    return True;
}


impl JacConsole._resolve_stream(file: any = None) -> any {
    return file if file is not None else sys.stdout;
}


impl JacConsole.print(*args: any, **kwargs: any) -> None {
    style = kwargs.pop('style', None);
    file = kwargs.pop('file', None);
    kwargs.pop('markup', None);
    kwargs.pop('highlight', None);
    processed: list = [(a.text if isinstance(a, Content) else a) for a in args];
    self._renderer.emit_raw(processed, self._resolve_stream(file), style, kwargs);
}

impl JacConsole.status(*args: any, **kwargs: any) -> AbstractContextManager {
    return self._renderer.status_ctx(list(args), kwargs);
}

impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    self._renderer.emit([Span(f"{prefix} {message}", 'success')]);
}

impl JacConsole.error(
    message: str, hint: str | None = None, emoji: bool = True
) -> None {
    prefix = '✖' if emoji and self.use_emoji else '[ERROR]';
    self._renderer.emit(
        [Span(f"{prefix} Error:", 'error'), Span(f" {message}", None)], sys.stderr
    );
    if hint {
        hint_prefix = '💡' if self.use_emoji else 'HINT:';
        self._renderer.emit([Span(f"{hint_prefix} {hint}", 'muted')], sys.stderr);
    }
}

impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    self._renderer.emit([Span(f"{prefix} {message}", 'warning')], sys.stderr);
}

impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    self._renderer.emit([Span(f"{prefix} {message}", 'info')]);
}

impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    self._renderer.header(title, version);
}

impl JacConsole.print_urls(urls: any, symbol: str = '') -> None {
    items = list(urls.items()) if isinstance(urls, dict) else list(urls);
    self._renderer.urls(items, symbol);
}

impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    self._renderer.next_steps(steps, title);
}

impl JacConsole.print_list(
    items: list[str], style: str = 'success', symbol: str = ''
) -> None {
    sym = symbol or ('✔' if self.use_emoji else '*');
    for item in items {
        self._renderer.emit([Span(f"  {sym}", style), Span(f" {item}", None)]);
    }
}

impl JacConsole.print_table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    self._renderer.table(headers, rows, title);
}

@contextmanager
impl JacConsole.spinner(text: str) -> object {
    with self._renderer.spinner_ctx(text) as s {
        yield s;
    }
}

impl JacConsole.print_elapsed_time(seconds: float) -> None {
    if seconds < 1 {
        ms = seconds * 1000;
        self._renderer.emit([Span("  Done in ", 'muted'), Span(f"{ms:.0f}ms", 'time')]);
    } else {
        self._renderer.emit(
            [Span("  Done in ", 'muted'), Span(f"{seconds:.1f}s", 'time')]
        );
    }
}

impl JacConsole.print_file_change(filepath: str, action: str = 'changed') -> None {
    import from datetime { datetime }
    timestamp = datetime.now().strftime('%H:%M:%S');
    emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
    color_map = {'changed': 'warning', 'created': 'success', 'deleted': 'error'};
    emoji = emoji_map.get(action, '📝') if self.use_emoji else action.upper();
    role = color_map.get(action, 'info');
    self._renderer.emit(
        [
            Span(f"[{timestamp}]", 'muted'),
            Span(f" {emoji} {action.capitalize()}:", role),
            Span(f" {filepath}", None)
        ]
    );
}

impl JacConsole.print_watching(pattern: str, count: int) -> None {
    watch_emoji = '👀 ' if self.use_emoji else '[WATCHING] ';
    self._renderer.emit([Span(f"{watch_emoji}Watching for changes...", 'info')]);
    self._renderer.emit(
        [
            Span("   Monitoring: ", 'muted'),
            Span(pattern, 'bright_white'),
            Span(f" ({count} files)", 'muted')
        ]
    );
}

impl _get_console -> JacConsole {
    global _console_instance;
    if _console_instance is None {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        _console_instance = Jac.get_console();
    }
    return _console_instance;
}
