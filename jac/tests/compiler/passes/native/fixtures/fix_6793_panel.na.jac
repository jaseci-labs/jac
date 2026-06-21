"""Panel module for issue #6793 regression test.

Imports SelectItem from selector and uses `list[SelectItem]` in a function
annotation — the exact pattern that triggered E5090 in the TUI's overlay.

Also imports SessionState/make_state from `state` WITHOUT using them.  This
unused diamond import is deliberate: it models the TUI where intermediate
modules pull in `state` for symbols used on code paths the minimal repro
doesn't exercise.  Because the symbols are not referenced, the entry-level
type-check never eagerly resolves `state` (and thus `selector`) into the
hub, so on the JIR-cached incremental build the dep-sweep re-inferred this
module's `list[SelectItem]` annotation before `selector` was registered —
leaving SelectItem as <Unknown> (E5090).  Removing the unused `state`
import makes the bug stop reproducing.
"""

import from fix_6793_selector { SelectItem, make_item, item_label }
import from fix_6793_state { SessionState, make_state }

def:pub panel_sum(items: list[SelectItem]) -> int {
    total: int = 0;
    for item in items {
        total = total + item_label(item);
    }
    return total;
}

def:pub panel_step(n: int) -> int {
    return n;
}
