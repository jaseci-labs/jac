"""Edge polarity must only remove the narrowing the conjunction never licensed."""

obj Foo {
    has bar: bool = False;
}

obj Other {
    has baz: int = 0;
}

def take_other(o: Other) {
    print(o);
}

def take_foo(f: Foo) {
    print(f);
}

# A lone guard still narrows both edges.
def single_guard(x: (Foo | Other)) {
    if isinstance(x, Foo) {
        take_foo(x);
    } else {
        take_other(x);
    }
}

# The true edge of a conjunction still narrows: every conjunct holds there.
def conjunction_true_edge(x: (Foo | Other)) {
    if isinstance(x, Foo) and x.bar {
        take_foo(x);
    }
}

# Every conjunct carries the same predicate, so the false edge is the negation
# of that one predicate and still narrows.
def uniform_conjunction(x: (Foo | Other)) {
    if isinstance(x, Foo) and isinstance(x, Foo) {
        take_foo(x);
    } else {
        take_other(x);
    }
}

# Negating a conjunction swaps the edges: the false edge of the negation is the
# true edge of the conjunction and still narrows.
def negated_conjunction(x: (Foo | Other)) {
    if not (isinstance(x, Foo) and x.bar) {
        print(x);
    } else {
        take_foo(x);
    }
}

# A disjunction whose every branch narrows still narrows both edges.
def full_disjunction(x: (Foo | Other | None)) {
    if isinstance(x, Foo) or isinstance(x, Other) {
        print(x.bar if isinstance(x, Foo) else x.baz);
    } else {
        print(x);
    }
}

# The false edge of a disjunction still subtracts every disjunct it matched.
def disjunction_false_edge(x: (Foo | Other), flag: bool) {
    if isinstance(x, Foo) or flag {
        print(x);
    } else {
        take_other(x);
    }
}
