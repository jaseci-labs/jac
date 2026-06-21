"""State module for issue #6793 regression test — defines SessionState.

Imports selector (matching the TUI's state.na.jac which imports from
select_list).  This cross-dependency is critical: `state` is imported by
EVERY module in the chain (entry, core, handler, panel) but `state` itself
imports `selector`, so the defining module for SelectItem sits *below* the
heavily-shared `state` node.  That shape is what produces the bad dep-sweep
order on a JIR-cached build.  Mirrors the TUI's state module.
"""

import from fix_6793_selector { SelectItem, make_item, item_label }

obj:pub SessionState {
    has id: int;
}

def:pub make_state(v: int) -> SessionState {
    return SessionState(id=v);
}
