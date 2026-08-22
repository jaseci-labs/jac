"""Fixture: obj postinit must run in the generated JS constructor."""

obj:pub Wired {
    has base: int = 2,
        doubled: int = 0;

    def postinit {
        self.doubled = self.base * 2;
    }
}

obj:pub OnlyPost {
    def postinit {
        print("side effect");
    }
}

def:pub component -> JsxElement {
    op = OnlyPost();
    return <div>{Wired().doubled}{op is not None}</div>;
}
