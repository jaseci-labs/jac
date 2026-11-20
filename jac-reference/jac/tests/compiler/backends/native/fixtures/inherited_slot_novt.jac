"""The same probe with no method override, to isolate the header disagreement.

`inherited_slot_child.jac` overrides `bump`, so the child needs a vtable
while the base may not carry one, and `adopt_imported_bases` declines to
reassign across that disagreement. This variant overrides nothing. If the
inherited slots lower here and not there, the header check is the cause; if
they refuse here too, the cause is upstream of it.
"""

import from .inherited_slot_base { SlotBase }

obj SlotChildFlat(SlotBase) {
    has own_field: int = 0;

    def store_inherited(v: int) {
        self.depth = v;
    }

    def read_inherited -> int {
        return self.depth;
    }
}

def probe_flat(v: int) -> int {
    c = SlotChildFlat();
    c.store_inherited(v);
    return c.read_inherited();
}
