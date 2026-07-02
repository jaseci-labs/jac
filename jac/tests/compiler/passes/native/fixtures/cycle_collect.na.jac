obj Node {
    has next: Node | None = None;
}

with entry {
    a: Node = Node();
    b: Node = Node();
    a.next = b;
    b.next = a;
    a = None;
    b = None;
    print("cycle_collect OK");
}
