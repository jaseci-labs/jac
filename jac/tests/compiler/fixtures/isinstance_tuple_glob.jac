"""A tuple-of-types bound to a name is a valid `isinstance` second argument.

`isinstance(x, (A, B))` and `isinstance(x, TABLE)` are the same call at
runtime -- Python accepts a tuple of classes by value, not just as a literal
at the call site. The checker only read the literal form, so every named
rejection table in the compiler narrowed its subject to `tuple` instead of to
the classes the table holds.

The bare class `tuple` is the inverse trap: it shares the table type's class
but is not a value, and reading it as an empty table silenced the guard
entirely -- `isinstance(x, tuple)` narrowed nothing in either branch (#8330).
"""

obj Base {
    has kind: str = "base";
}

obj Leaf(Base) {
    has tag: str = "leaf";
}

obj Twig(Base) {
    has size: int = 1;
}

glob LEAF_ONLY: tuple[type[Leaf]] = (Leaf, ),
     LEAF_OR_TWIG: tuple[(type[Leaf], type[Twig])] = (Leaf, Twig),
     ERASED: tuple = (Leaf, Twig);

def takes_base(nd: Base) -> str {
    return nd.kind;
}

def tag_of(nd: Base) -> str {
    if isinstance(nd, LEAF_ONLY) {
        return nd.tag;
    }
    return "";
}

def still_a_base(nd: Base) -> str {
    if isinstance(nd, LEAF_ONLY) {
        return takes_base(nd);
    }
    return "";
}

def either_of(nd: Base) -> int {
    if isinstance(nd, LEAF_OR_TWIG) {
        return nd.size if isinstance(nd, Twig) else 0;
    }
    return 0;
}

def erased_table(nd: Base) -> str {
    if isinstance(nd, ERASED) {
        return takes_base(nd);
    }
    return "";
}

def bare_class_positive(x: (str | tuple)) -> tuple {
    if isinstance(x, tuple) {
        return x + ("tail", );
    }
    return (x, );
}

def bare_class_negative(x: (type | tuple | None)) -> str {
    if isinstance(x, tuple) {
        return "tuple";
    } elif x is not None {
        return x.__name__;
    }
    return "*";
}
