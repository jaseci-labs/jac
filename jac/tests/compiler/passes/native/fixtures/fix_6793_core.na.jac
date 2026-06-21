"""Core module for issue #6793 regression test.

Pass-through link: entry -> core -> handler.  Imports `state` without using
its symbols (the deliberate unused diamond import, same as handler/panel).
Mirrors the TUI's tui_core module.
"""

import from fix_6793_handler { handler_step }
import from fix_6793_state { SessionState, make_state }

def:pub core_run(count: int) -> int {
    return handler_step(count);
}
