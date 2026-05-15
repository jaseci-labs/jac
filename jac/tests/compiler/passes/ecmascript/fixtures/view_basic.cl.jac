"""Phase 1 `view` declarator: statement templates and control flow.

Exercises the `view` keyword as sugar for `def:pub -> JsxElement`: a
statement-based body with sibling JSX statements, nested JSX elements, a
view calling another view, a `has`-field with a nested `def` handler,
view-body-level `if`/`else` and `for`, and a bare `return;` guard.
"""

obj Item {
    has label: str,
        done: bool = False;
}

"""A small presentational view."""
view Badge(text: str) {
    <span class="badge">{text}</span>
}

view ItemRow(item: Item) {
    if item.done {
        <Badge text="done" />
    } else {
        <Badge text="todo" />
    }
    <div class="row">
        <span class="label">{item.label}</span>
    </div>
}

view ItemList(items: list[Item]) {
    has heading: str = "Items";

    def bump {
        heading = heading + "!";
    }

    <h2 onClick={bump}>{heading}</h2>
    if len(items) == 0 {
        <p class="empty">Nothing here.</p>
        return;
    }
    <p class="status">Showing items.</p>
    for it in items {
        <ItemRow key={jid(it)} item={it} />
    }
    <footer class="count">{len(items)} items</footer>
}
