"""`abc.ABC` is compile-time information, so it erases in a native unit.

Jac models abstractness itself: `abst` is the first-class spelling, and the
server lane synthesizes `@abstractmethod` from `Ability.is_abstract` rather
than reading it. The `ABC` base therefore adds nothing a native unit needs at
run time, and the archetype keeps its ordinary layout.

The method here is declared with `abst`, not with the Python decorator, which
is the boundary `test_native_method_kind_keywords` pins: the keyword forms
cross into native and the hand-written decorator spellings demote.
"""

import from abc { ABC }


obj Shape(ABC) {
    has n: int = 3;

    def area -> int abst;
}


obj Square(Shape) {
    def area -> int {
        return self.n * self.n;
    }
}


def run -> int {
    return Square(n=5).area();
}
