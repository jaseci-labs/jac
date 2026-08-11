"""Bug #CYCLE-TAINT-1 fixture, sibling module: REGISTRY's initializer
references the importing module's CONFIG while CONFIG is being resolved."""

import from checker_cycle_taint_main { CONFIG }

obj Reg {
    has defaults: dict = {};
}

glob REGISTRY = Reg() if CONFIG is None else Reg();
