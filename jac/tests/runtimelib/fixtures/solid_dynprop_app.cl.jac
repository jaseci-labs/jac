"""Solid dynamic prop / child reactivity fixture (P2.1 jsdom matrix).

A parent holds a `count` signal; a child `Display` component receives it as
a prop. Uses the `props: dict` idiom so `Display` reads `props["value"]`
directly inside the JSX expression — no destructuring — which keeps
`babel-preset-solid`'s getter chain intact:

  `<Display value={count()} />`
  → `createComponent(Display, { get value() { return count(); } })`

Inside `Display`, `{props["value"]}` is compiled to a reactive insertion
that reads through the getter on every update, tracking `count`.
"""

def:pub Display(props: dict) -> JsxElement {
    return <p data-testid="display">Value: {props["value"]}</p>;
}

def:pub app() -> JsxElement {
    has count: int = 0;
    return <div>
        <Display value={count} />
        <button data-testid="inc" onClick={lambda (e: any) { count = count + 1; }}>+</button>
    </div>;
}
