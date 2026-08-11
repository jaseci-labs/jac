"""Bug #CYCLE-PRECISION-1 fixture, sibling module: REGISTRY's initializer
re-enters CONFIG mid-resolution AND, in the same evaluation window,
dereferences an attribute on JUNK, whose type is genuinely Unknown no matter
what CONFIG settles to (calling a non-callable int yields Unknown on both
ternary branches). JUNK.oops is a real E1032 that a window-based suppression
wrongly amnesties because JUNK's resolution overlaps the cycle."""

import from checker_cycle_precision_main { CONFIG }

glob N: int = 3;

obj Reg {
    has defaults: dict = {};
}

glob JUNK = (N if CONFIG is None else N)(),
     REGISTRY = Reg() if JUNK.oops is None else Reg();
