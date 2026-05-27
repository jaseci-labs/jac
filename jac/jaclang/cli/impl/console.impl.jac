"""Implementation of console utilities for terminal output.

Production-grade console with raw ANSI codes. User data is never processed
or modified - only internal CLI chrome (prefixes, symbols) gets styled.

`JacConsole` is the capability/routing facade; `ConsoleRenderer` is the ANSI
drawing backend it delegates to. Caller data flows as styleless `Span`s so it
is always emitted verbatim.
"""
import os;
import sys;
import from contextlib { contextmanager }

# ===============================================================================
# ANSI Color Codes - Raw and Simple
# ===============================================================================
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

# Map semantic style roles to raw ANSI. Roles are renderer-agnostic; this table
# is the ANSI renderer's palette.
glob _ANSI_ROLES: dict = {
         'success': GREEN,
         'error': RED,
         'warning': YELLOW,
         'info': CYAN,
         'muted': DIM,
         'highlight': CYAN,
         'url': BRIGHT_BLUE + UNDERLINE,
         'time': GREEN,
         'cyan': CYAN,
         'dim': DIM,
         'bright_white': BRIGHT_WHITE
     };

# ===============================================================================
# ConsoleRenderer (ANSI backend) Implementation
# ===============================================================================
"""Sync the renderer's capability flags with the facade's resolved decision."""
impl ConsoleRenderer.configure(use_emoji: bool, use_color: bool) -> None {
    self.use_emoji = use_emoji;
    self.use_color = use_color;
}

"""Write one composed line; colored spans wrap raw ANSI, data spans pass through.

A span with `style is None` (caller data) is emitted verbatim — no styling, no
interpretation — which is the trust boundary. Color is applied only when the
facade resolved `use_color = True`.
"""
impl ConsoleRenderer.emit(spans: list[Span], stream: any = None) -> None {
    out = stream if stream is not None else sys.stdout;
    parts: list[str] = [];
    for s in spans {
        if self.use_color and s.style is not None and _ANSI_ROLES.get(s.style) {
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

"""Emit raw print() args verbatim. User data is never modified.

Handles Windows console encoding (replacing unencodable chars) and broken
pipes. `style` is ignored by the ANSI backend — `print` is a pure passthrough.
"""
impl ConsoleRenderer.emit_raw(
    args: list, stream: any, style: str | None, kwargs: dict
) -> None {
    out = stream if stream is not None else sys.stdout;
    # Handle Windows console encoding - replace unencodable chars
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
        try {
            print(*processed_args, file=out, **kwargs);
        } except (BrokenPipeError, OSError) {
            return;
        }
    } else {
        try {
            print(*args, file=out, **kwargs);
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

"""Print a header with optional version, framed by terminal-width rules."""
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

"""Print a list of labeled URLs. Labels and URLs are caller data (verbatim)."""
impl ConsoleRenderer.urls(items: list, symbol: str = '') -> None {
    sym = symbol or ('➜' if self.use_emoji else '>');
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        self.emit(
            [
                Span("  ", None),
                Span(sym, 'cyan'),
                Span("  ", None),
                Span(padded_label, 'muted'),
                Span(" ", None),
                Span(str(url), 'url')
            ]
        );
    }
}

"""Print a titled list of next steps. Step text is caller data (verbatim)."""
impl ConsoleRenderer.next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    self.emit([Span("", None)]);
    self.emit([Span(f"{title}:", 'bright_white')]);
    for (i, step) in enumerate(steps, 1) {
        self.emit([Span(f"  {i}.", 'cyan'), Span(f" {step}", None)]);
    }
    self.emit([Span("", None)]);
}

"""Print a formatted table with colored headers. Cells are caller data."""
impl ConsoleRenderer.table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    if title {
        self.emit([Span(f"\n{title}:", 'bright_white')]);
    }
    col_widths: list[int] = [len(h) for h in headers];
    for row in rows {
        for (i, cell) in enumerate(row) {
            if i < len(col_widths) {
                col_widths[i] = max(col_widths[i], len(str(cell)));
            }
        }
    }
    # Header row: styled chrome, but separators around verbatim header text.
    header_spans: list[Span] = [];
    for (idx, (h, w)) in enumerate(zip(headers, col_widths)) {
        if idx > 0 {
            header_spans.append(Span(" | ", 'dim'));
        }
        header_spans.append(Span(h.ljust(w), 'bright_white'));
    }
    self.emit(header_spans);
    sep_len = sum(col_widths) + (len(col_widths) - 1) * 3;
    self.emit([Span('-' * sep_len, 'dim')]);
    # Data rows: cells emitted verbatim, only the separators styled.
    for row in rows {
        row_spans: list[Span] = [];
        for (i, cell) in enumerate(row) {
            if i > 0 {
                row_spans.append(Span(" | ", 'dim'));
            }
            width = col_widths[i] if i < len(col_widths) else 0;
            row_spans.append(Span(str(cell).ljust(width), None));
        }
        self.emit(row_spans);
    }
    self.emit([Span("", None)]);
}

"""Context manager for status during long operations."""
@contextmanager
impl ConsoleRenderer.status_ctx(args: list, kwargs: dict) -> object {
    if args {
        msg = args[0] if isinstance(args[0], str) else str(args[0]);
        self.emit([Span(msg, 'muted')]);
    }
    yield None;
}

"""Context manager for spinner during long operations."""
@contextmanager
impl ConsoleRenderer.spinner_ctx(text: str) -> object {
    self.emit([Span(f"{text}...", 'muted')]);
    try {
        yield None;
    } finally {
        self.emit([Span(" done", 'success')]);
    }
}

# ===============================================================================
# JacConsole facade Implementation
# ===============================================================================
"""Detect terminal capabilities once at construction, build the renderer via
the polymorphic factory, and push the capability decision to it.

`init` is Jac's constructor (`__init__`), which runs before `by postinit`
fields are set — so all renderer setup lives here in `postinit`, which runs
after fields are initialized. Plugins customize the backend by overriding
`_make_renderer`, not by re-implementing this.
"""
impl JacConsole.postinit -> None {
    self.use_emoji = JacConsole._should_use_emoji();
    self.use_color = JacConsole._should_use_color();
    self._renderer = self._make_renderer();
    self._renderer.configure(self.use_emoji, self.use_color);
}

"""Build the rendering backend. The base console renders with ANSI; plugins
override this to return a different `ConsoleRenderer` (e.g. jac-super's Rich
backend).
"""
impl JacConsole._make_renderer -> ConsoleRenderer {
    return ConsoleRenderer();
}

"""Check if emoji should be used based on environment."""
impl JacConsole._should_use_emoji -> bool {
    if os.environ.get('NO_EMOJI') or os.environ.get('TERM') == 'dumb' {
        return False;
    }
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') {
        return False;
    }
    return True;
}

"""Check if color should be used based on environment.

Checks: NO_COLOR env, TERM=dumb, and isatty() for CI/pipe/server safety.
"""
impl JacConsole._should_use_color -> bool {
    # Respect NO_COLOR standard (https://no-color.org/)
    if os.environ.get('NO_COLOR') {
        return False;
    }
    # Dumb terminals don't support ANSI
    if os.environ.get('TERM') == 'dumb' {
        return False;
    }
    # Not a TTY = CI, pipe, server, captured output - no colors
    try {
        if not sys.stdout.isatty() {
            return False;
        }
    } except Exception {
        return False;
    }
    return True;
}

"""Resolve the output stream for a `file=` kwarg.

Single source of truth for stream routing: `None` means default stdout; an
explicit stream (`sys.stderr` or an arbitrary file object) is returned as-is.
Both the facade and plugin renderers route through this so the
stdout/stderr/other decision can never diverge between implementations.
"""
impl JacConsole._resolve_stream(file: any = None) -> any {
    return file if file is not None else sys.stdout;
}

"""Print to stdout. User data passes through unchanged - no processing.

`Content`-wrapped args are unwrapped to their raw text; `style`/`markup`/
`highlight` kwargs are stripped for renderer compatibility; `file=` routes via
the shared stream resolver.
"""
impl JacConsole.print(*args: any, **kwargs: any) -> None {
    style = kwargs.pop('style', None);
    file = kwargs.pop('file', None);
    kwargs.pop('markup', None);
    kwargs.pop('highlight', None);
    processed: list = [(a.text if isinstance(a, Content) else a) for a in args];
    self._renderer.emit_raw(processed, self._resolve_stream(file), style, kwargs);
}

"""Context manager for status during long operations."""
impl JacConsole.status(*args: any, **kwargs: any) -> object {
    return self._renderer.status_ctx(list(args), kwargs);
}

"""Print a success message with green checkmark."""
impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    self._renderer.emit([Span(prefix, 'success'), Span(f" {message}", None)]);
}

"""Print an error message with optional hint."""
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

"""Print a warning message in yellow."""
impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    self._renderer.emit(
        [Span(prefix, 'warning'), Span(f" {message}", None)], sys.stderr
    );
}

"""Print an info message in cyan."""
impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    self._renderer.emit([Span(prefix, 'info'), Span(f" {message}", None)]);
}

"""Print a header with optional version."""
impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    self._renderer.header(title, version);
}

"""Print a list of labeled URLs."""
impl JacConsole.print_urls(urls: any, symbol: str = '') -> None {
    items = list(urls.items()) if isinstance(urls, dict) else list(urls);
    self._renderer.urls(items, symbol);
}

"""Print a bordered box with next steps."""
impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    self._renderer.next_steps(steps, title);
}

"""Print a list of items with colored symbols. Items are caller data."""
impl JacConsole.print_list(
    items: list[str], style: str = 'success', symbol: str = ''
) -> None {
    sym = symbol or ('✔' if self.use_emoji else '*');
    for item in items {
        self._renderer.emit([Span(f"  {sym}", style), Span(f" {item}", None)]);
    }
}

"""Print a formatted table with colored headers."""
impl JacConsole.print_table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    self._renderer.table(headers, rows, title);
}

"""Context manager for spinner during long operations."""
@contextmanager
impl JacConsole.spinner(text: str) -> object {
    with self._renderer.spinner_ctx(text) as s {
        yield s;
    }
}

"""Print elapsed time in a human-friendly format."""
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

"""Print file change notification with timestamp. Filepath is caller data."""
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

"""Print file watching status. Pattern is caller data."""
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

# ===============================================================================
# Module-level function implementations
# ===============================================================================
"""Get the console instance using the hook system, allowing plugins to override."""
impl _get_console -> JacConsole {
    global _console_instance;
    if _console_instance is None {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        # Capability detection and renderer wiring happen in `postinit` at
        # construction; no post-construction `init()` call is needed.
        _console_instance = Jac.get_console();
    }
    return _console_instance;
}
