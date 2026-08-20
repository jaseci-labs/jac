"""The defining half of the inherited-slot probe: a base obj with slots.

Paired with `inherited_slot_child.jac`. The base declares the slots and one
overridable method, so a subclass that overrides it needs a vtable while the
base's own header may not carry one -- which is the configuration
`layout_pass.adopt_imported_bases` refuses to reassign.
"""

obj SlotBase {
    has tag: int = 0,
        depth: int = 0;

    def bump -> int {
        return self.tag;
    }
}
