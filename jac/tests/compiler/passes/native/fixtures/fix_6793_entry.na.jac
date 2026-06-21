"""Entry module for issue #6793 regression test.

Imports `state` directly AND `core` (which reaches `state` again transitively)
— the diamond at the top of the chain, mirroring the TUI's tui.na.jac which
imports TuiState directly and also tui_core.  SelectItem (the type that fails)
is reached only transitively: entry -> core -> handler -> panel -> selector.

Build this module twice in separate processes (see the regression test): the
first build writes the JIR cache, the second reads it.  Before the fix the
second build failed with E5090 (list[<Unknown>]) because JIR does not
serialize Expr.type, so the cached native tree arrived untyped and the
dep-sweep re-inference could not repair the deeply-reached SelectItem link.
"""

import from fix_6793_state { SessionState, make_state }
import from fix_6793_core { core_run }

def:pub run() -> int {
    return core_run(5);
}

with entry {
    print(run());
}
