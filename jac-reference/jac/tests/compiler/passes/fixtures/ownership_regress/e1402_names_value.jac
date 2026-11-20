"""E1402 must name the sealed value ('shared'), not the storage root."""

obj Node {
    has val: int = 0,
        left: Node | None = None;
}

with entry {
    shared = Node(val=5);
    a = Node(val=1);
    a.left = shared;
    print(a.val);
}
