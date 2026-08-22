"""Base of a three-module chain, with a same-file subclass so it carries a vtable.

`DeepSibling` exists only so `DeepBase` is somebody's parent inside its own
unit, which is what gives it a vtable slot and keeps the header agreeing all
the way down the chain. Without it this fixture would measure the flat-base
disagreement instead of the linearization truncation it is here to measure.
"""

obj DeepBase {
    has slot_a: int = 0;

    def read_a -> int {
        return self.slot_a;
    }
}

obj DeepSibling(DeepBase) {
    has sib: int = 0;
}
