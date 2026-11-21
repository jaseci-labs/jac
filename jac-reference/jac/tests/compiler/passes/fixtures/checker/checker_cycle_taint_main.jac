"""Bug #CYCLE-TAINT-1 fixture, main module: CONFIG's initializer reaches
through the sibling module and back into CONFIG itself mid-resolution.

Resolving CONFIG walks: CONFIG -> REGISTRY (sibling) -> its initializer
`Reg() if CONFIG is None else Reg()` -> CONFIG again (re-entrant, in-flight).
The re-entrant leg only feeds an `is None` test, so its type never matters:
the ternary is Reg either way, REGISTRY settles to Reg, and CONFIG settles
to dict (Reg.defaults). A checker that freezes or diagnoses the transient
in-flight Unknown instead reports a spurious attribute error on
`REGISTRY.defaults`, a spurious arg-type error on `len(CONFIG)`, and W1051
noise -- and pins CONFIG to Unknown forever.
"""

import from checker_cycle_taint_reg { REGISTRY }

glob CONFIG = REGISTRY.defaults;

def show() -> int {
    return len(CONFIG);
}

with entry {
    print(show());
}
