"""Capability single-source-of-truth tests for the Rich renderer.

The base `JacConsole` is the facade that decides terminal capabilities once
(`use_color`, `use_emoji`) from NO_COLOR / NO_EMOJI / isatty / TERM. The
renderer must *consume* those decisions via `configure`, not re-derive them
independently — otherwise the facade's documented flags and what actually
reaches the terminal can disagree (e.g. Rich emitting color under a forced
terminal even though the facade resolved `use_color = False`).

These tests pin that `RichRenderer.configure` propagates the facade's
capability flags into the Rich consoles it builds.
"""

import from jac_super.plugin.console { RichRenderer }


test "renderer honors use_color=False (no_color propagated)" {
    r = RichRenderer();
    r.configure(use_emoji=True, use_color=False);
    assert r._console.no_color == True , f"stdout console ignored use_color=False; no_color={r._console.no_color!r}";
    assert r._console_stderr.no_color == True , f"stderr console ignored use_color=False; no_color={r._console_stderr.no_color!r}";
}


test "renderer honors use_color=True (color enabled)" {
    r = RichRenderer();
    r.configure(use_emoji=True, use_color=True);
    assert not r._console.no_color , f"console forced no_color despite use_color=True; no_color={r._console.no_color!r}";
}


test "renderer honors use_emoji=False" {
    r = RichRenderer();
    r.configure(use_emoji=False, use_color=True);
    assert r._console._emoji == False , f"console ignored use_emoji=False; _emoji={r._console._emoji!r}";
}
