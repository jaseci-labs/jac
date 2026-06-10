"""Rich-enhanced console backend for jac-super.

This module provides `RichRenderer`, a `ConsoleRenderer` subclass that draws
with Rich, plus `JacSuperConsole`, a `JacConsole` that installs it. The facade's
15-method surface is inherited unchanged — jac-super customizes *only* the
renderer, so the surface can never drift from the base (the failure mode behind
issue #5995).

Trust boundary
---------------
Rich treats every plain `str` handed to `Console.print` as a *rich document*:
it parses `[tag]` markup, auto-highlights numbers/paths, and reflows to the
terminal width. Caller data must never be interpreted that way. This renderer
enforces the boundary structurally: data arrives as `Span`s with `style is
None`, which are appended to a `rich.text.Text` as plain runs (Text is never
markup-parsed, never auto-highlighted). Rich styling is applied only to spans
that carry a tool-authored style role.
"""
import sys;
import from contextlib { contextmanager }
import from rich.console { Console as RichConsole }
import from rich.panel { Panel }
import from rich.table { Table }
import from rich.text { Text }
import from rich.theme { Theme }
import from jaclang.cli.console { JacConsole, ConsoleRenderer, Span }

"""Rich rendering backend. Overrides the ANSI primitives with Rich equivalents."""
obj RichRenderer(ConsoleRenderer) {
    with entry {
        JAC_THEME = Theme(
            {
                'success': 'green',
                'error': 'red',
                'warning': 'yellow',
                'info': 'cyan',
                'url': 'underline green',
                'muted': 'dim white',
                'highlight': 'cyan',
                'time': 'green',
                'bright_white': 'bright_white'
            }
        );
    }

    has _console: RichConsole by postinit,
        _console_stderr: RichConsole by postinit;

    def postinit {
        # Build provisional consoles so the `by postinit` fields are
        # initialized; `configure` rebuilds them once the facade resolves
        # capabilities.
        self._build_consoles();
    }

    """Honor the facade's resolved capabilities, then rebuild the Rich consoles.

    Capability detection has a single source of truth (the base
    `JacConsole.init`); `no_color` / `emoji` are taken from it rather than
    relying on Rich's independent auto-detection.
    """
    def configure(use_emoji: bool, use_color: bool) {
        self.use_emoji = use_emoji;
        self.use_color = use_color;
        self._build_consoles();
    }

    """Construct the stdout/stderr Rich consoles from the capability flags."""
    def _build_consoles {
        self._console = self._make_console(stderr=False);
        self._console_stderr = self._make_console(stderr=True);
    }

    """Build one themed Rich console honoring the capability flags.

    Rich's `stderr=True` (not `file=sys.stderr`) resolves the stream per call,
    preserving the `sys.stderr = io.StringIO()` redirection in-process CLI tests
    rely on (issue #5995, Bug 1).
    """
    def _make_console(stderr: bool = False) -> RichConsole {
        return RichConsole(
            theme=self.JAC_THEME,
            stderr=stderr,
            no_color=(not self.use_color),
            emoji=self.use_emoji
        );
    }

    """Pick the themed console for a stream, or None for an arbitrary stream."""
    def _console_for(stream: any) -> any {
        target = stream if stream is not None else sys.stdout;
        if target is sys.stderr {
            return self._console_stderr;
        }
        if target is sys.stdout {
            return self._console;
        }
        return None;
    }

    """Render one composed line. Styled spans carry a theme role; data spans
    (style is None) are appended as plain `Text` runs and emitted verbatim.
    """
    def emit(spans: list[Span], stream: any = None) -> None {
        console = self._console_for(stream);
        if console is None {
            # Arbitrary stream: write verbatim, no styling.
            print(''.join(s.text for s in spans), file=stream);
            return;
        }
        t = Text();
        for s in spans {
            if s.style is not None {
                t.append(s.text, style=s.style);
            } else {
                t.append(s.text);
            }
        }
        console.print(t, soft_wrap=True);
    }

    """Emit raw print() args. Markup parsing and auto-highlight are disabled and
    soft-wrap is on so user content passes through unchanged; an arbitrary
    stream is written verbatim via builtin print.
    """
    def emit_raw(args: list, stream: any, style: (str | None), kwargs: dict) -> None {
        console = self._console_for(stream);
        if console is None {
            print(*args, file=stream, **kwargs);
            return;
        }
        kwargs.setdefault('markup', False);
        kwargs.setdefault('highlight', False);
        kwargs.setdefault('soft_wrap', True);
        if style {
            console.print(*args, style=style, **kwargs);
        } else {
            console.print(*args, **kwargs);
        }
    }

    """Header: title (and version) in highlight role, no rule (Rich house style)."""
    def header(title: str, version: (str | None) = None) {
        if version {
            self.emit([Span(f"{title} v{version}", 'highlight')]);
        } else {
            self.emit([Span(title, 'highlight')]);
        }
    }

    """Next steps in a bordered Rich Panel. Step text is data (verbatim)."""
    def next_steps(steps: list[str], title: str = 'Next Steps') {
        body = Text();
        for (i, step) in enumerate(steps, 1) {
            if i > 1 {
                body.append("\n");
            }
            body.append(f"  {i}  ", style='highlight');
            body.append(step);
        }
        panel = Panel(body, title=title, border_style='cyan', padding=(0, 1));
        self._console.print(panel);
    }

    """Rich Table. Header and cell values are data, wrapped in `Text` so they
    are never markup-parsed.
    """
    def table(headers: list[str], rows: list[list[str]], title: (str | None) = None) {
        tbl = Table(title=title, show_header=True, header_style='cyan');
        for header in headers {
            tbl.add_column(Text(str(header)));
        }
        for row in rows {
            tbl.add_row(*[Text(str(cell)) for cell in row]);
        }
        self._console.print(tbl);
    }

    """Rich status context. The status text is wrapped in `Text`."""
    @contextmanager
    def status_ctx(args: list, kwargs: dict) -> object {
        safe = [(Text(a) if isinstance(a, str) else a) for a in args];
        with self._console.status(*safe, **kwargs) as st {
            yield st;
        }
    }

    """Rich spinner context."""
    @contextmanager
    def spinner_ctx(text: str) -> object {
        with self._console.status(
            Text(text, style='highlight'), spinner='dots'
        ) as st {
            yield st;
        }
    }
}

"""Jac console facade that renders with Rich.

It inherits the entire `JacConsole` method surface and overrides only the
renderer it installs — no output methods are re-implemented.
"""
obj JacSuperConsole(JacConsole) {
    def _make_renderer -> ConsoleRenderer {
        return RichRenderer();
    }
}
