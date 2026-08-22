"""Fullstack Jac app fixture: server function + client component with has (useState) and async can with entry (useEffect)."""

def:pub get_items -> list {
    return [{"name": "alpha"}, {"name": "beta"}];
}

def:pub app -> JsxElement {
    has items: list = [];

    async can with entry {
        items = await get_items();
    }

    <div id="app">
        <h1>Items</h1>
        <ul>{[<li>{item.name}</li> for item in items]}</ul>
    </div>
}
