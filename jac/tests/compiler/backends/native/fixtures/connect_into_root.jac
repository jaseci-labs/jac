"""Connects that put an edge into root, or both ways, are not anchors.

Each connect sits in a function of its own, so each is refused by name and
demotes only its function."""

node N {
    has val: int;
}

def into_root(a: N) {
    a ++> root;
}

def from_left(a: N) {
    root <++ a;
}

def both_from_root(a: N) {
    root <++> a;
}

def both_to_root(a: N) {
    a <++> root;
}

with entry {
    a = N(val=1);
    into_root(a);
    from_left(a);
    both_from_root(a);
    both_to_root(a);
    print("done", a.val);
}
