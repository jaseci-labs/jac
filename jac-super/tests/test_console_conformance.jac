"""Conformance tests for the JacConsole contract.

The global `console` from `jaclang.cli.console` is a process-wide singleton
that plugins may override (jac-super installs `JacSuperConsole`). These
tests pin the parts of the base contract that must remain true regardless
of which implementation is installed:

  1. `console.error` / `console.warning` honor `sys.stderr` redirection
     (the standard `sys.stderr = io.StringIO()` test idiom must capture them).
  2. `console.print` emits user content verbatim — no soft-wrap reflow,
     no markup stripping — so JSON, paths, and diagnostic snippets stay
     byte-exact.

A plugin console that breaks any of these regresses every in-process CLI
caller silently. Keep this file passing for every implementation that
appears at `jaclang.cli.console.console`.
"""

import io;
import sys;
import from jaclang.cli.console { console }


# Force the lazy global `console` to materialize now, with the real
# `sys.stdout` / `sys.stderr` in place — before any test redirects them.
# This makes the stderr-binding bug manifest deterministically: every test
# below starts with an already-constructed console, mirroring real CLI usage
# where the singleton is built at startup and tests redirect stdio later.
glob _ = console.print;


test "console.error honors sys.stderr redirection" {
    captured = io.StringIO();
    saved = sys.stderr;
    sys.stderr = captured;
    try {
        console.error("CONFORM-ERROR-MARKER");
    } finally {
        sys.stderr = saved;
    }
    text = captured.getvalue();
    assert "CONFORM-ERROR-MARKER" in text , f"console.error did not honor sys.stderr redirection; captured={text!r}";
}


test "console.warning honors sys.stderr redirection" {
    captured = io.StringIO();
    saved = sys.stderr;
    sys.stderr = captured;
    try {
        console.warning("CONFORM-WARNING-MARKER");
    } finally {
        sys.stderr = saved;
    }
    text = captured.getvalue();
    assert "CONFORM-WARNING-MARKER" in text , f"console.warning did not honor sys.stderr redirection; captured={text!r}";
}


test "console.error hint honors sys.stderr redirection" {
    captured = io.StringIO();
    saved = sys.stderr;
    sys.stderr = captured;
    try {
        console.error("CONFORM-ERROR-WITH-HINT", hint="CONFORM-HINT-MARKER");
    } finally {
        sys.stderr = saved;
    }
    text = captured.getvalue();
    assert "CONFORM-ERROR-WITH-HINT" in text , f"console.error did not honor sys.stderr redirection; captured={text!r}";
    assert "CONFORM-HINT-MARKER" in text , f"console.error hint did not honor sys.stderr redirection; captured={text!r}";
}


test "console.print emits long content verbatim (no soft-wrap reflow)" {
    long_line = "A" * 300;
    captured = io.StringIO();
    saved = sys.stdout;
    sys.stdout = captured;
    try {
        console.print(long_line);
    } finally {
        sys.stdout = saved;
    }
    out = captured.getvalue().rstrip("\n");
    assert "\n" not in out , f"console.print soft-wrapped output (300-char input → multiple lines); first 200={out[:200]!r}";
    assert long_line in out , f"console.print did not emit input verbatim; first 200={out[:200]!r}";
}


test "console.print preserves bracketed content verbatim" {
    bracketed = "diagnostic snippet: [root()-->][?:Task] arr[0] dict['key']";
    captured = io.StringIO();
    saved = sys.stdout;
    sys.stdout = captured;
    try {
        console.print(bracketed);
    } finally {
        sys.stdout = saved;
    }
    out = captured.getvalue();
    assert "[root()-->]" in out , f"console.print stripped bracketed markup-like content; captured={out!r}";
    assert "[?:Task]" in out , f"console.print stripped bracketed markup-like content; captured={out!r}";
    assert "arr[0]" in out and "dict['key']" in out , f"console.print stripped bracketed code-like content; captured={out!r}";
}
