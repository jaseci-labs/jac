"""Fixture for testing that fields assigned in postinit are registered in the symbol table."""

obj MyObj {
    has name: str = "hello";

    def postinit -> None;
}

impl MyObj.postinit -> None {
    self.hub: dict[str, int] = {'a': 1};
}

with entry {
    n = MyObj();
    print(n.hub);
}
