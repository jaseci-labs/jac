"""Renderer-protocol / anti-drift tests.

Step 3 of the console architecture: the 15-method surface lives exactly once,
on the `JacConsole` facade, which delegates low-level rendering to a swappable
`ConsoleRenderer`. A plugin (jac-super) customizes output by supplying its own
renderer — it must NOT re-implement the facade methods. If it does, the two
implementations drift: a new method added to the facade silently misses the
plugin, and per-method trust-boundary discipline has to be re-applied by hand
(the exact failure mode that produced issue #5995).

These tests pin that single-source-of-truth structurally.
"""

import from jaclang.cli.console { JacConsole, console }
import from jac_super.plugin.console { JacSuperConsole }


# Every public method of the console surface. The plugin must inherit each of
# these from the facade unchanged — customization happens in the renderer.
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
     ];


test "plugin does not re-implement any facade method (single source of truth)" {
    overridden = [];
    for m in _FACADE_METHODS {
        base_fn = getattr(JacConsole, m);
        plug_fn = getattr(JacSuperConsole, m);
        if plug_fn is not base_fn {
            overridden.append(m);
        }
    }
    assert not overridden , f"plugin overrides facade methods (should override only the renderer): {overridden}";
}


test "the live console exposes a swappable renderer" {
    # Materialize the global singleton and reach the real console object.
    console.print;
    c = console.__getattr__('print').__self__ if console?.__getattr__ else console;
    assert hasattr(c, '_renderer') , "console facade has no _renderer to delegate to";
    # Under jac-super the installed renderer must be the Rich one.
    assert type(c._renderer).__name__ == 'RichRenderer' , f"expected RichRenderer, got {type(
        c._renderer
    ).__name__}";
}
