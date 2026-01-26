"""Fullstack Jac app fixture: server function + client component with has (useState) and async can with entry (useEffect)."""

def:pub get_items -> list {
    return [{"name": "alpha"}, {"name": "beta"}];
}

cl def:pub app() -> any {
    has items: list = [];

    async can with entry {
        items = await get_items();
    }

    return
        <div id="app">
            <h1>Items</h1>
            <ul>
                {items.map(
                    lambda item: dict -> any { return <li>{item.name}</li>; }
                )}
            </ul>
        </div>;
}
