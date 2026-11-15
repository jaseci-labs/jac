obj Link {
    has name: str,
        after: Link | None = None;
}

obj Tree {
    has label: str,
        kids: list[Tree] = [];
}

obj Hub {
    has name: str,
        spokes: dict[str, Hub] = {};
}

with entry {
    print([Link(name="a", after=Link(name="b"))]);
    print(Link(name="c"));
    print([Tree(label="r", kids=[Tree(label="x")])]);
    print(Tree(label="y"));
    print({"h": Hub(name="p", spokes={"q": Hub(name="q")})});
    print(Hub(name="z"));
}
