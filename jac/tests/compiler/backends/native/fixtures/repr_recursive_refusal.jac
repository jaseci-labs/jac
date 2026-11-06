"""str of a recursive object whose subclass holds a field the text helper refuses."""

obj Node {
    has key: int = 0,
        left: Node | None = None;
}

obj Entry(Node) {
    has raw: ptr[u8] = ptr[u8](),
        count: int = 0;
}

def show(key: int) -> int {
    tree = Node(key=key, left=Node(key=key + 1));
    return len(str(tree));
}

def plain(key: int) -> int {
    return key + 1;
}
