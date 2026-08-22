"""isinstance narrowing is applied to each declared union member on its own."""

obj Base {
    has label: str = "b";
}

obj Mid(Base) {
    has mid: int = 0;
}

obj Leaf(Mid) {
    has leaf: int = 0;
}

obj Other {
    has weight: int = 0;
}

def take_leaf(l: Leaf) {
    print(l);
}

def take_mid(m: Mid) {
    print(m);
}

# `Leaf` sits below the filter and `Base` above it, so the guard leaves the
# one alone and narrows the other. Narrowing the union as a whole kept only
# the members below the filter and dropped `Base` entirely, which claimed a
# `Base` that passes the guard is a `Leaf`.
def mixed_union(x: (Leaf | Base)) {
    take_mid(x if isinstance(x, Mid) else Mid());
    if isinstance(x, Mid) {
        take_leaf(x);
    }
}

# Both members are below the filter, so both survive untouched.
def all_below_filter(x: (Leaf | Mid)) {
    if isinstance(x, Base) {
        take_mid(x);
    }
}

# A member unrelated to the filter cannot pass it and drops.
def unrelated_member_drops(x: (Base | Other)) {
    if isinstance(x, Mid) {
        take_mid(x);
    }
}

# A tuple filter is a disjunction: each member is narrowed against the
# alternatives it relates to, not paired with every one of them.
def tuple_filter(x: (Leaf | Other)) {
    if isinstance(x, (Mid, Other)) {
        print(x);
    }
}
