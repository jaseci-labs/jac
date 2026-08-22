"""The false edge of a conjunction cannot exclude a single conjunct's type."""

obj Foo {
    has bar: bool = False;
}

obj Other {
    has baz: int = 0;
}

def take_other(o: Other) {
    print(o);
}

# `not (isinstance(x, Foo) and x.bar)` holds when x is a Foo whose `bar` is
# false, so the else branch may not exclude Foo.
def and_chain_false_edge(x: (Foo | Other)) {
    if isinstance(x, Foo) and x.bar {
        print(x.bar);
    } else {
        take_other(x);
    }
}

# Same shape reached through an early return rather than an else block.
def and_chain_fallthrough(x: (Foo | Other)) -> None {
    if isinstance(x, Foo) and x.bar {
        return;
    }
    take_other(x);
}

# A disjunction is unsound in the mirror direction: `isinstance(x, Foo) or flag`
# is true whenever `flag` is, so the true edge may not conclude Foo.
def or_chain_true_edge(x: (Foo | Other), flag: bool) {
    if isinstance(x, Foo) or flag {
        print(x.bar);
    }
}
