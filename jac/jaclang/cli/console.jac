"""Console utilities for terminal output.

This module provides utilities for terminal output using pure Python.
It is split into two collaborators:

- `JacConsole` — the *facade*. It owns the 15-method output surface, terminal
  capability detection (NO_COLOR / NO_EMOJI / isatty / TERM), and stream
  routing. Every method composes its output once and delegates the actual
  drawing to a renderer.
- `ConsoleRenderer` — the swappable *backend*. The base class renders with raw
  ANSI. Plugins (like jac-super) subclass it to render with Rich, and install
  their renderer on the facade. They do NOT re-implement the facade methods, so
  the surface can never drift between implementations.

The split makes terminal styling a structural trust boundary: caller data is
carried as `Span`s with no style, which every renderer must emit verbatim —
markup/ANSI is never interpreted in user content.
"""
import os;
import sys;
import from contextlib { contextmanager, AbstractContextManager }
import from typing { cast }

"""Caller-supplied text that must be emitted verbatim.

Terminal markup (Rich's `[tag]...[/tag]`, raw ANSI) is an injection surface:
a path, URL, diagnostic snippet, or source line that happens to contain
square brackets must never be interpreted as styling. Wrapping such a value
in `Content` marks it as tainted so every renderer emits its characters
unchanged. Passing a bare `str` to the data-bearing console methods is already
treated as `Content` by default; this type exists so callers can be explicit
and self-documenting at trust boundaries.
"""
obj Content {
    has text: str;

    def __str__ -> str {
        return self.text;
    }
}

"""One run of text on a line, with an optional semantic style role.

`style` names a *role* ('success', 'error', 'muted', 'url', …), not a color —
each renderer maps roles to its own palette. `style is None` marks the run as
caller data: renderers emit it verbatim, never styled or markup-parsed. Lines
are composed by the facade as `list[Span]` and handed to `ConsoleRenderer.emit`.
"""
obj Span {
    has text: str,
        style: str | None = None;
}

"""Swappable rendering backend for the console facade.

The base implementation renders with raw ANSI escape codes. Subclasses override
these primitives to render differently (e.g. jac-super's Rich backend). The
facade calls `configure` once after capability detection, then routes every
method through these primitives.
"""
obj ConsoleRenderer {
    has use_emoji: bool = True,
        use_color: bool = True;

    def configure(use_emoji: bool, use_color: bool) -> None;
    def emit(spans: list[Span], stream: any = None) -> None;
    def emit_raw(args: list, stream: any, style: str | None, kwargs: dict) -> None;
    def header(title: str, version: str | None = None) -> None;
    def urls(items: list, symbol: str = '') -> None;
    def next_steps(steps: list[str], title: str = 'Next Steps') -> None;
    def table(
        headers: list[str], rows: list[list[str]], title: str | None = None
    ) -> None;

    @contextmanager
    def status_ctx(args: list, kwargs: dict) -> object;

    @contextmanager
    def spinner_ctx(text: str) -> object;
}

"""Console utility class for terminal output in Jac CLI.

This is the facade. It detects capabilities and delegates drawing to a
`ConsoleRenderer`. The base console uses the ANSI renderer; plugins install a
different renderer via the `get_console` hook without overriding these methods.
"""
obj JacConsole {
    has use_emoji: bool = True,
        use_color: bool = True,
        _renderer: ConsoleRenderer by postinit;

    def postinit -> None;
    def _make_renderer -> ConsoleRenderer;
    static def _should_use_emoji -> bool;
    static def _should_use_color -> bool;
    def _resolve_stream(file: any = None) -> any;
    def print(*args: any, **kwargs: any) -> None;
    def status(*args: any, **kwargs: any) -> AbstractContextManager;
    def success(message: str, emoji: bool = True) -> None;
    def error(message: str, hint: str | None = None, emoji: bool = True) -> None;
    def warning(message: str, emoji: bool = True) -> None;
    def info(message: str, emoji: bool = True) -> None;
    def print_header(title: str, version: str | None = None) -> None;
    def print_urls(urls: any, symbol: str = '') -> None;
    def print_next_steps(steps: list[str], title: str = 'Next Steps') -> None;
    def print_list(items: list[str], style: str = 'success', symbol: str = '') -> None;
    def print_table(
        headers: list[str], rows: list[list[str]], title: str | None = None
    ) -> None;

    @contextmanager
    def spinner(text: str) -> object;

    def print_elapsed_time(seconds: float) -> None;
    def print_file_change(filepath: str, action: str = 'changed') -> None;
    def print_watching(pattern: str, count: int) -> None;
}

# Lazy initialization to avoid circular imports
glob _console_instance: JacConsole | None = None;

def _get_console -> JacConsole;

# Basic proxy class that lazily initializes the console on first access
# This allows plugins to override via the hook system while avoiding circular imports
class _ConsoleProxy {
    def __getattr__(self: _ConsoleProxy, name: str) -> any {
        return getattr(_get_console(), name);
    }
}

# Export the proxy as console - provides clean attribute access with lazy initialization.
# The annotation lets the type checker resolve `console.print(...)` etc. against the
# JacConsole interface; the cast satisfies the proxy-to-JacConsole assignment.
glob console: JacConsole = cast(JacConsole, _ConsoleProxy());
