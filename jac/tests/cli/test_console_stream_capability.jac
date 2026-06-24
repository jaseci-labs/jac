"""Per-stream TTY capability tests for the console renderer (issue #6499).

The facade resolves `use_color` once at construction from `sys.stdout.isatty()`.
That flag is a process-wide *master* switch (NO_COLOR, TERM=dumb). But a single
process can write to many streams — `sys.stderr` redirected to a file,
`print(file=...)` targeting an arbitrary sink — and ANSI escapes only render on
a real TTY. Styling a non-TTY stream corrupts captured output.

CI/headless shells never see this because stdout isn't a TTY there, so
`use_color` is naturally False. These tests force `use_color=True` to mimic an
interactive terminal, then assert non-TTY target streams stay plain text —
pinning the per-stream gating that `emit`/`emit_raw` must do at emit time.
"""

import io;
import sys;
import from jaclang.cli.console { JacConsole, ConsoleRenderer, Span }


"""Build a console whose renderer believes color is on, mimicking an interactive
terminal where stdout was a TTY at construction time."""
def _make_color_console -> JacConsole {
    c = JacConsole();
    c.use_color = True;
    c._renderer.configure(use_emoji=True, use_color=True);
    return c;
}


test "emit() to a non-TTY stream emits no ANSI even with use_color=True" {
    r = ConsoleRenderer();
    r.configure(use_emoji=True, use_color=True);
    target = io.StringIO();
    r.emit([Span("chrome", "error"), Span(" data", None)], target);
    text = target.getvalue();
    assert "\x1b[" not in text , f"ANSI escapes leaked into non-TTY emit target: {text!r}";
    assert "chrome" in text and " data" in text , f"emit dropped content: {text!r}";
}


test "emit() to a TTY-mocking stream still styles when use_color=True" {
    # A stream that reports isatty()=True must still get styled output, so the
    # per-stream check doesn't regress the normal interactive-terminal path.
    r = ConsoleRenderer();
    r.configure(use_emoji=True, use_color=True);
    target = _FakeTty();
    r.emit([Span("chrome", "error")], target);
    text = target.getvalue();
    assert "\x1b[31m" in text , f"emit stopped styling a TTY target: {text!r}";
    assert "\x1b[0m" in text , f"emit dropped RESET on a TTY target: {text!r}";
}


test "error() to redirected stderr emits no ANSI when stderr is not a TTY" {
    c = _make_color_console();
    captured = io.StringIO();
    saved = sys.stderr;
    sys.stderr = captured;
    try {
        c.error("STREAM-CAP-ERROR-MARKER");
    } finally {
        sys.stderr = saved;
    }
    text = captured.getvalue();
    assert "\x1b[" not in text , f"ANSI escapes leaked into non-TTY stderr: {text!r}";
    assert "STREAM-CAP-ERROR-MARKER" in text , f"error message lost: {text!r}";
}


test "error() hint to redirected stderr emits no ANSI when stderr is not a TTY" {
    c = _make_color_console();
    captured = io.StringIO();
    saved = sys.stderr;
    sys.stderr = captured;
    try {
        c.error("STREAM-CAP-ERR-HINT", hint="STREAM-CAP-HINT-MARKER");
    } finally {
        sys.stderr = saved;
    }
    text = captured.getvalue();
    assert "\x1b[" not in text , f"ANSI escapes leaked into non-TTY stderr: {text!r}";
    assert "STREAM-CAP-HINT-MARKER" in text , f"hint lost: {text!r}";
}


test "warning() to redirected stderr emits no ANSI when stderr is not a TTY" {
    c = _make_color_console();
    captured = io.StringIO();
    saved = sys.stderr;
    sys.stderr = captured;
    try {
        c.warning("STREAM-CAP-WARNING-MARKER");
    } finally {
        sys.stderr = saved;
    }
    text = captured.getvalue();
    assert "\x1b[" not in text , f"ANSI escapes leaked into non-TTY stderr: {text!r}";
    assert "STREAM-CAP-WARNING-MARKER" in text , f"warning message lost: {text!r}";
}


test "print(file=StringIO) with style= emits no ANSI on a non-TTY target" {
    c = _make_color_console();
    target = io.StringIO();
    c.print("STREAM-CAP-FILE-TARGET", file=target, style="green");
    text = target.getvalue();
    assert "\x1b[" not in text , f"ANSI escapes leaked into non-TTY file= target: {text!r}";
    assert "STREAM-CAP-FILE-TARGET" in text , f"print content lost: {text!r}";
}


test "emit_raw() to a non-TTY stream emits no ANSI even with use_color=True" {
    r = ConsoleRenderer();
    r.configure(use_emoji=True, use_color=True);
    target = io.StringIO();
    r.emit_raw(["raw-target"], target, "green", {});
    text = target.getvalue();
    assert "\x1b[" not in text , f"ANSI escapes leaked into non-TTY emit_raw target: {text!r}";
    assert "raw-target" in text , f"emit_raw dropped content: {text!r}";
}


test "use_color=False master switch still suppresses ANSI even on a TTY target" {
    # The master off-switch wins: NO_COLOR/TERM=dumb must suppress styling even
    # when the target stream is a TTY. Per-stream gating is additive, not a
    # replacement for the global flag.
    r = ConsoleRenderer();
    r.configure(use_emoji=True, use_color=False);
    target = _FakeTty();
    r.emit([Span("chrome", "error")], target);
    text = target.getvalue();
    assert "\x1b[" not in text , f"master use_color=False failed to suppress ANSI on TTY: {text!r}";
}


# A minimal stream that lies about being a TTY, for the positive-direction tests.
obj _FakeTty {
    has _buf: list[str] = [];

    def write(s: str) -> int {
        self._buf.append(s);
        return len(s);
    }

    def flush -> None {
        return;
    }

    def isatty -> bool {
        return True;
    }

    def getvalue -> str {
        return ''.join(self._buf);
    }
}
