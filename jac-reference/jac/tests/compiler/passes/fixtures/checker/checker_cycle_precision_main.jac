"""Bug #CYCLE-PRECISION-1 fixture, main module: the same settling import
cycle as #CYCLE-TAINT-1, while the sibling initializer also contains a
genuine, cycle-independent type error evaluated in the same resolution
window. The cycle-transient suppressions must hold (CONFIG settles to dict,
no spurious assignment/argument errors) while the genuine error still fires.
"""

import from checker_cycle_precision_reg { REGISTRY }

glob CONFIG = REGISTRY.defaults;

def show -> int {
    return len(CONFIG);
}

with entry {
    print(show());
}
