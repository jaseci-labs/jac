"""`isinstance` on an optional operand.

`None` is an instance of nothing, so the check short-circuits to False
without ever inspecting the option's payload -- the payload is undefined
when the tag is 0, and the user-archetype path reads a vtable off the
object, so an unguarded unwrap would dereference garbage.
"""

obj Base {
    has tag: int = 0;
}

obj Leaf(Base) {
    has extra: int = 0;
}

obj Twig(Base) {
    has other: int = 0;
}

def opt_single(pick: int) -> bool {
    val: (Base | None) = None;
    if pick == 1 {
        val = Leaf();
    } elif pick == 2 {
        val = Twig();
    }
    return isinstance(val, Leaf);
}

def opt_tuple(pick: int) -> bool {
    val: (Base | None) = None;
    if pick == 1 {
        val = Leaf();
    } elif pick == 2 {
        val = Twig();
    }
    return isinstance(val, (Leaf, Twig));
}

def opt_negative(pick: int) -> bool {
    val: (Base | None) = None;
    if pick == 1 {
        val = Twig();
    }
    return isinstance(val, Leaf);
}

def opt_through_static(pick: int) -> bool {
    val: (Base | None) = None;
    if pick == 1 {
        val = Leaf();
    }
    return Gate.is_leaf(val);
}

obj Gate {
    static def is_leaf(nd: (Base | None)) -> bool {
        return isinstance(nd, Leaf);
    }
}
