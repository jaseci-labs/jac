"""The defining half of the inherited-slot probe: a base obj with slots.

Paired with `inherited_slot_child.jac`. The base declares the slots and one
overridable method, so a subclass in another module may override it; the base
carries a vtable in its own module for that reason, and the child's header
agrees with it.
"""

obj SlotBase {
    has tag: int = 0,
        depth: int = 0;

    def bump -> int {
        return self.tag;
    }
}
