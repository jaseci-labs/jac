"""A `from`-imported Python base is a run-time dependency and must refuse.

The bare-import spelling of this module already refuses, pinned in
`type_position_retained_base.jac`. Naming the base through a `from` import
changes nothing about what the archetype needs: `Event` has to be there for
`Holder` to mean what it says, and no native unit can supply it.

Lowering this module anyway produced a `Holder` with everything it inherits
silently missing -- a wrong binary in place of a refusal.
"""

import from threading { Event }


obj Holder(Event) {
    has n: int = 3;
}


def run -> int {
    return Holder(n=5).n;
}
