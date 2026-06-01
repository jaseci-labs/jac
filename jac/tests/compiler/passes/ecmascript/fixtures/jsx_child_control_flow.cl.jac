"""Phase 2: control flow at JSX child position via `{...}` slots.

A `{...}` slot at JSX child position is a statement-template: control
flow (`if`/`for`/`while`/`match`/`switch`/`with`/`try`) and `return`
guards can appear inside. The slot lowers to an IIFE that runs the body
and returns either the accumulated JSX children fragment (when JSX is
emitted statement-by-statement) or the value of the last expression.

Single-expression slots (today's `{name}` or `{<jsx/>}`) keep their
zero-cost lowering as plain `JsxExpression` nodes -- the slot path only
fires when the body begins with a statement keyword or has multiple
statements.
"""

obj Item {
    has label: str,
        done: bool = False;
}

"""Renders a list using a statement-position `for` inside a slot."""
def:pub ItemList(items: list[Item]) -> JsxElement {
    return
        <ul class="items">
            {for it in items {
                <li key={it.label} class={"done" if it.done else "todo"}>{it.label}</li>
            }}
        </ul>;
}

"""`if`/`else` directly inside a slot, contributing different children."""
def:pub Greeting(name: str) -> JsxElement {
    return
        <div class="card">
            {if name == "" {
                <p>Hello, stranger</p>
            } else {
                <h1>Hello, {name}</h1>
                <p>Welcome back.</p>
            } }
        </div>;
}

"""Mixes static siblings with a slot-driven `for` in the same parent."""
def:pub Mixed(items: list[Item]) -> JsxElement {
    return
        <section>
            <header>Items</header>
            {for it in items {
                <article key={it.label}>{it.label}</article>
            }}
            <footer>End</footer>
        </section>;
}

"""Nested control flow inside one slot."""
def:pub Conditional(items: list[Item], show: bool) -> JsxElement {
    return
        <div>
            {if show {
                for it in items {
                    <span key={it.label}>{it.label}</span>
                }
            }}
        </div>;
}
