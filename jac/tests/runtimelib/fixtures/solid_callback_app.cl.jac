"""Solid callback prop fixture (P2.3 jsdom matrix).

A parent passes a plain function (`on_click`) as the `handler` prop to a
child `Clicker` component. The child wires it to `onClick`. This proves that
the dom-expressions JSX path does not misread a function-valued prop as a
reactive accessor — the handler must fire exactly once per click, not
spuriously on prop access or mount.
"""

def:pub Clicker(label: str, handler: any) -> JsxElement {
    return <button data-testid="child-btn" onClick={handler}>{label}</button>;
}

def:pub app() -> JsxElement {
    has clicks: int = 0;

    def on_click(e: any) -> None {
        clicks = clicks + 1;
    }

    return <div>
        <Clicker label="click me" handler={on_click} />
        <p data-testid="click-count">Clicks: {clicks}</p>
    </div>;
}
