"""Client that sv-imports both a reader function and a writer walker.

The walker (AddItem) must land in the client endpoint-effects manifest as a
writer so its calls invalidate cached reads (#7650).
"""

sv import from sv_walker_effects { Item, list_items, AddItem }

def:pub app -> JsxElement {
    has items: list[Item] = [];

    async can with entry {
        items = await list_items();
    }

    async def add(text: str) -> None {
        _ = await (root spawn AddItem(text=text));
        items = await list_items();
    }

    return <div>{[<p key={i}>{it.text}</p> for (i, it) in enumerate(items)]}</div>;
}
