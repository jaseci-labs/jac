"""Test fixture for reactive effects (can with entry in client context).

Note: useEffect import is auto-injected from @jac/runtime when `can with entry/exit` is used.
"""

cl {
    def:pub app() -> any {
        has items: list = [];
        has loading: bool = True;

        # Mount effect - runs once on component mount
        async can with entry {
            items = await fetch_items();
            loading = False;
        }

        return <div>
            <p>Items: {items}</p>
            <p>Loading: {loading}</p>
        </div>;
    }
}
