"""Test fixture for has statement combining inside abilities (functions)."""

# has statements inside a function should be combined
def app() -> any {
    has count: int = 0;
    has name: str = "test";
    has enabled: bool = True;

    # Do something
    count = count + 1;

    return count;
}

# has statements in client-side function (typically in .cl.jac files)
cl {
    def:pub counter() -> JsxElement {
        has value: int = 0;
        has label: str = "Counter";
        has visible: bool = True;

        return <div>{label}: {value}</div>;
    }
}

# Method with has statements should also combine
obj Widget {
    has id: str;

    def render() -> str {
        has prefix: str = "<";
        has suffix: str = ">";
        has content: str = "";

        return prefix + content + suffix;
    }
}
