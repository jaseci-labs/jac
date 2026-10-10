"""Connects that put an edge into root, or both ways, are not anchors."""

node N {
    has val: int;
}

with entry {
    a = N(val=1);
    a ++> root;
    root <++ a;
    root <++> a;
    a <++> root;
    print("done", a.val);
}
