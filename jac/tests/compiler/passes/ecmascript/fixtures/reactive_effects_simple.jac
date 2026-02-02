"""Test fixture for simple reactive effects (can with entry in client context)."""

cl {
    def:pub app() -> JsxElement {
        has count: int = 0;

        async can with entry {
            count = 1;
        }

        return <div>{count}</div>;
    }
}
