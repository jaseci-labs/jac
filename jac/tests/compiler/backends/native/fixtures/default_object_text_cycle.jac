obj Tree {
    has name: str,
        parent: Tree | None = None,
        kids: list[Tree] = [];
}

obj Pair {
    has left: Pair | None = None,
        label: str = "p";
}

with entry {
    top = Tree(name="top");
    kid = Tree(name="kid", parent=top);
    top.kids.append(kid);
    print(top);
    print(kid);
    a = Pair(label="a");
    b = Pair(left=a, label="b");
    a.left = b;
    print(a, b);
    lone = Pair();
    print(lone, [lone, lone]);
}
