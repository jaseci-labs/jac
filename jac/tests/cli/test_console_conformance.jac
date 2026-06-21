"""Conformance tests for the JacConsole contract.

The global `console` from `jaclang.cli.console` is a process-wide singleton.
The base renderer now produces Rich-style output (box panels/tables, animated
spinner) in pure Jac; these tests pin the parts of the contract that must hold
regardless of which renderer is installed:

  1. `console.error` / `console.warning` honor `sys.stderr` redirection
     (the standard `sys.stderr = io.StringIO()` test idiom must capture them).
  2. `console.print` emits user content verbatim — no soft-wrap reflow,
     no markup stripping — so JSON, paths, and diagnostic snippets stay
     byte-exact.
  3. Every data-bearing method emits caller data verbatim: terminal markup
     (`[tag]...`) is an injection surface and must never be interpreted.

A renderer that breaks any of these regresses every in-process CLI caller
silently. Keep this file passing for every implementation that appears at
`jaclang.cli.console.console`.
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


# ---------------------------------------------------------------------------
# Trust-boundary conformance: every method that carries caller-supplied DATA
# must emit that data verbatim, regardless of bracket content. Markup is an
# injection surface; a console that interprets `[...]` in data corrupts paths,
# URLs, diagnostics, and source snippets. These pin the contract for ALL
# data-bearing methods, not just `print`.
# ---------------------------------------------------------------------------

# A token a markup parser would consume-and-strip if (incorrectly) interpreted
# as markup. Survival of this exact substring proves the data field reached the
# terminal verbatim.
glob _BRACKET_BAIT: str = "[root()-->]";


def _cap_stdout(fn: any) -> str {
    captured = io.StringIO();
    saved = sys.stdout;
    sys.stdout = captured;
    try {
        fn();
    } finally {
        sys.stdout = saved;
    }
    return captured.getvalue();
}


test "console.print honors file= routing to an arbitrary stream" {
    # The base console forwards `file=` to builtin print(); a renderer that
    # drops it silently sends output to the wrong stream (issue: file= drop).
    target = io.StringIO();
    sink = io.StringIO();
    saved = sys.stdout;
    sys.stdout = sink;
    try {
        console.print("ROUTED-TO-TARGET", file=target);
    } finally {
        sys.stdout = saved;
    }
    assert "ROUTED-TO-TARGET" in target.getvalue() , f"console.print did not route to file=; target={target.getvalue()!r} sink={sink.getvalue()!r}";
}


test "console.print_urls emits URL data verbatim (no markup interpretation)" {
    out = _cap_stdout(
        lambda : console.print_urls({"Local": f"http://{_BRACKET_BAIT}host:8080/"})
    );
    assert _BRACKET_BAIT in out , f"print_urls interpreted bracket data as markup; captured={out!r}";
}


test "console.print_list emits item data verbatim" {
    out = _cap_stdout(lambda : console.print_list([f"item {_BRACKET_BAIT} one"]));
    assert _BRACKET_BAIT in out , f"print_list interpreted bracket data as markup; captured={out!r}";
}


test "console.print_next_steps emits step data verbatim" {
    out = _cap_stdout(lambda : console.print_next_steps([f"run {_BRACKET_BAIT} now"]));
    assert _BRACKET_BAIT in out , f"print_next_steps interpreted bracket data as markup; captured={out!r}";
}


test "console.print_file_change emits filepath verbatim" {
    out = _cap_stdout(
        lambda : console.print_file_change(f"/tmp/{_BRACKET_BAIT}/x.jac")
    );
    assert _BRACKET_BAIT in out , f"print_file_change interpreted bracket data as markup; captured={out!r}";
}


test "console.print_watching emits pattern verbatim" {
    out = _cap_stdout(lambda : console.print_watching(f"**/{_BRACKET_BAIT}/*.jac", 3));
    assert _BRACKET_BAIT in out , f"print_watching interpreted bracket data as markup; captured={out!r}";
}


test "console.print_table emits cell data verbatim" {
    out = _cap_stdout(
        lambda : console.print_table(["Col"], [[f"cell {_BRACKET_BAIT}"]])
    );
    assert _BRACKET_BAIT in out , f"print_table interpreted bracket data as markup; captured={out!r}";
}
