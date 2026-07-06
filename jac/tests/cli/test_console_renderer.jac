"""Renderer-protocol / surface tests for the console architecture.

The 15-method output surface lives exactly once, on the `JacConsole` facade,
which delegates low-level drawing to a swappable `ConsoleRenderer`. Rich-style
output (box panels/tables, animated spinner) is reimplemented in pure Jac inside
the base renderer — no third-party dependency, no separate plugin.

These tests pin that single-source-of-truth structure: the facade owns the
surface, the renderer owns the drawing primitives, and the live console
delegates to a real renderer.
"""

import from jaclang.cli.console { JacConsole, ConsoleRenderer, console }


# Every public method of the console surface. Each must live on the facade.
glob _FACADE_METHODS: list[str] = [
         'print',
         'status',
         'success',
         'error',
         'warning',
         'info',
         'print_header',
         'print_urls',
         'print_next_steps',
         'print_list',
         'print_table',
         'spinner',
         'print_elapsed_time',
         'print_file_change',
         'print_watching'
     ],
     # The drawing primitives the facade delegates to. The base renderer must
     # implement each (box panels/tables + spinner are reimplemented here in Jac).
     _RENDERER_PRIMITIVES: list[str] = [
         'configure',
         'emit',
         'emit_raw',
         'header',
         'urls',
         'next_steps',
         'table',
         'status_ctx',
         'spinner_ctx'
     ];


test "facade exposes the full console surface" {
    missing = [
        m
        for m in _FACADE_METHODS
        if not hasattr(JacConsole, m)
    ];
    assert not missing , f"facade is missing surface methods: {missing}";
}


test "renderer implements every drawing primitive (incl. box/spinner)" {
    missing = [
        p
        for p in _RENDERER_PRIMITIVES
        if not hasattr(ConsoleRenderer, p)
    ];
    assert not missing , f"renderer is missing primitives: {missing}";
}


test "the live console delegates to a real renderer" {
    # Materialize the global singleton and reach the real console object.
    console.print;
    c = console.__getattr__('print').__self__ if console?.__getattr__ else console;
    assert hasattr(c, '_renderer') , "console facade has no _renderer to delegate to";
    assert isinstance(c._renderer, ConsoleRenderer) , f"expected a ConsoleRenderer, got {type(
        c._renderer
    ).__name__}";
}
