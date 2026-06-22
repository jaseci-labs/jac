"""Capability single-source-of-truth tests for the console renderer.

The `JacConsole` facade decides terminal capabilities once (`use_color`,
`use_emoji`) from NO_COLOR / NO_EMOJI / isatty / TERM, then pushes them to the
renderer via `configure`. The renderer must *consume* those decisions, not
re-derive them independently — otherwise the facade's documented flags and what
actually reaches the terminal can disagree.

These tests pin that `ConsoleRenderer.configure` propagates the facade's
capability flags, and that the facade wires its resolved decision into the
renderer it builds.
"""

import from jaclang.cli.console { ConsoleRenderer, JacConsole }


test "renderer honors use_color=False via configure" {
    r = ConsoleRenderer();
    r.configure(use_emoji=True, use_color=False);
    assert r.use_color == False , f"renderer ignored use_color=False; use_color={r.use_color!r}";
}


test "renderer honors use_color=True via configure" {
    r = ConsoleRenderer();
    r.configure(use_emoji=True, use_color=True);
    assert r.use_color == True , f"renderer ignored use_color=True; use_color={r.use_color!r}";
}


test "renderer honors use_emoji=False via configure" {
    r = ConsoleRenderer();
    r.configure(use_emoji=False, use_color=True);
    assert r.use_emoji == False , f"renderer ignored use_emoji=False; use_emoji={r.use_emoji!r}";
}


test "facade pushes its resolved capabilities into the renderer" {
    # `postinit` detects capabilities then calls `_renderer.configure(...)`, so
    # the renderer's flags must match the facade's resolved decision.
    c = JacConsole();
    assert c._renderer.use_color == c.use_color , f"renderer.use_color {c._renderer.use_color!r} != facade {c.use_color!r}";
    assert c._renderer.use_emoji == c.use_emoji , f"renderer.use_emoji {c._renderer.use_emoji!r} != facade {c.use_emoji!r}";
}
