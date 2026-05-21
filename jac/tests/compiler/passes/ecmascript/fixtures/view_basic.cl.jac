"""JSX slots: statement templates and control flow inside `{...}` slots.

Exercises the unified `{...}` slot model: each top-level `{...}` slot in
JSX child position can carry statement-form templates -- multiple JSX
children, control flow that yields content (`if`/`for`/`while`/etc.),
and a `return;` guard. Components are plain `def:pub -> JsxElement`
functions whose JSX `return` value contains the slots.
"""

obj Item {
    has label: str,
        done: bool = False;
}

"""A bare divider component."""
def:pub Divider -> JsxElement {
    return
        <hr class="divider"/>;
}

"""A small presentational component."""
def:pub Badge(text: str) -> JsxElement {
    return
        <span class="badge">{text}</span>;
}

def:pub ItemRow(item: Item) -> JsxElement {
    return
        <div class="row">
            {if item.done {
                <Badge text="done"/>
            } else {
                <Badge text="todo"/>
            } }
            <span class="label">{item.label}</span>
        </div>;
}

def:pub ItemList(items: list[Item]) -> JsxElement {
    has heading: str = "Items";

    def bump {
        heading = heading + "!";
    }

    return
        <>
            <h2 onClick={bump}>{heading}</h2>
            {if len(items) == 0 {
                <p class="empty">Nothing here.</p>
                return;
            }}
            <p class="status">Showing items.</p>
            <Divider/>
            {for it in items {
                <ItemRow key={jid(it)} item={it}/>
            }}
            <footer class="count">{len(items)} items</footer>
        </>;
}
