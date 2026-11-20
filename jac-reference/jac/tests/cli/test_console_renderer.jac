"""Renderer-protocol / surface tests for the console architecture.

The 15-method output surface lives exactly once, on the `JacConsole` facade,
which delegates low-level drawing to a swappable `ConsoleRenderer`. Rich-style
output (box panels/tables, animated spinner) is reimplemented in pure Jac inside
the base renderer — no third-party dependency, no separate plugin.

These tests pin that single-source-of-truth structure: the facade owns the
surface, the renderer owns the drawing primitives, and the live console
delegates to a real renderer.
"""

import from jaclang.cli.console { JacConsole, ConsoleRenderer, Span, console }

test "live status text refreshes while the current module is still compiling" {
    import io;
    import from jaclang.cli.console { _Spinner }
    stream = io.StringIO();
    spinner = _Spinner("", stream, ["."], "", "", interval=0);
    ticks: list[int] = [0];
    def progress -> str {
        ticks[0] += 1;
        if ticks[0] == 2 {
            spinner._stop.set();
        }
        return f"0 completed · 1 active · {ticks[0]}.0s";
    }
    spinner.update(progress);
    spinner._run();
    assert "0 completed · 1 active · 1.0s" in stream.getvalue();
    assert "0 completed · 1 active · 2.0s" in stream.getvalue();
}


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
    console_dyn: any = console;
    c = (
        console_dyn.__getattr__('print').__self__
            if console_dyn?.__getattr__
            else console_dyn
    );
    assert hasattr(c, '_renderer') , "console facade has no _renderer to delegate to";
    assert isinstance(c._renderer, ConsoleRenderer) , f"expected a ConsoleRenderer, got {type(
        c._renderer
    ).__name__}";
}


obj _RecordingStatus {
    has cleared: int = 0;

    def update(text: str = '') -> None {
        return;
    }

    def clear {
        self.cleared += 1;
    }
}


test "an emit while a status line is live clears that line first" {
    # A warning printed mid-compile used to land on the spinner's line; every
    # emit now wipes the live status line, and the spinner redraws after it.
    import io;
    renderer = ConsoleRenderer();
    live = _RecordingStatus();
    renderer._active_status = live;
    out = io.StringIO();
    renderer.emit([Span("hello", None)], out);
    renderer.emit_raw(["world"], out, None, {});
    assert live.cleared == 2 , (
        f"emit and emit_raw must each clear the live status line, saw {live.cleared}"
    );
    assert "hello" in out.getvalue() and "world" in out.getvalue();
}
