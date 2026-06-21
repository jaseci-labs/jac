"""Handler module for issue #6793 regression test.

Pass-through link in the chain: entry -> core -> handler -> panel.  Imports
`state` (SessionState/make_state) WITHOUT using the symbols — the same
deliberate unused diamond import as panel, so `state` is imported at every
chain level.  Mirrors the TUI's screen module.
"""

import from fix_6793_panel { panel_step }
import from fix_6793_state { SessionState, make_state }

def:pub handler_step(n: int) -> int {
    return panel_step(n);
}
