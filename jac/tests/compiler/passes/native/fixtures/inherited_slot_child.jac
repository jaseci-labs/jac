"""A child obj whose methods store to and read slots its base declares.

This is the minimal shape of the four refusals the pass base chain's arrival
exposed: `UniPass.transform` stores `ir_out`, `UniPass.traverse` stores
`cur_node`, and `JsxIntrinsicGuardPass.before_pass` reads `ir_in` -- every
one a slot declared on an ancestor in a different module, with both modules
inside the same native unit.

`store_inherited` is the write half and `read_inherited` the read half.
`bump` is overridden so the child needs a vtable, which is the header
disagreement `adopt_imported_bases` declines to reassign across.
"""

import from .inherited_slot_base { SlotBase }

obj SlotChild(SlotBase) {
    has own_field: int = 0;

    def bump -> int {
        return self.tag + 1;
    }

    def store_inherited(v: int) {
        self.depth = v;
    }

    def read_inherited -> int {
        return self.depth;
    }

    def store_own(v: int) {
        self.own_field = v;
    }
}

def probe_inherited(v: int) -> int {
    c = SlotChild();
    c.store_inherited(v);
    c.store_own(v);
    return c.read_inherited() + c.own_field;
}
