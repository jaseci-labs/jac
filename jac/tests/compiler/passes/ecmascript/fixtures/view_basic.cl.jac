"""Phase 1 `defview` declarator: statement templates and control flow.

Exercises the `defview` keyword as sugar for `def:pub -> JsxElement`: a
statement-based body with sibling JSX statements, nested JSX elements, a
defview calling another defview, a `has`-field with a nested `def` handler,
defview-body-level `if`/`else` and `for`, a bare `return;` guard, and the
no-parameter-list form (`defview Name { ... }`, parens omitted).
"""

obj Item {
    has label: str,
        done: bool = False;
}

"""A bare divider — no parameter list, parens omitted."""
defview Divider {
    <hr class="divider" />
}

"""A small presentational view."""
defview Badge(text: str) {
    <span class="badge">{text}</span>
}

defview ItemRow(item: Item) {
    if item.done {
        <Badge text="done" />
    } else {
        <Badge text="todo" />
    }
    <div class="row">
        <span class="label">{item.label}</span>
    </div>
}

defview ItemList(items: list[Item]) {
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
    <Divider />
    for it in items {
        <ItemRow key={jid(it)} item={it} />
    }
    <footer class="count">{len(items)} items</footer>
}
