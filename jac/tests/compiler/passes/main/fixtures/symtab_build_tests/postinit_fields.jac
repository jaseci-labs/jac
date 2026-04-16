"""Fixture for testing that fields declared with 'by postinit' are registered in the symbol table."""

obj MyObj {
    has name: str = "hello";
    has hub: dict[str, int] by postinit;

    def postinit -> None;
}

impl MyObj.postinit -> None {
    self.hub = {'a': 1};
}

with entry {
    n = MyObj();
    print(n.hub);
}
