"""Solid control-flow app for jsdom runtime verification (Branch 4).

End-to-end proof that the producer's lifted control flow compiles **and renders**
through `babel-preset-solid`, not just that we emit plausible JSX strings:

- a keyed list comprehension (`[<li key={label}> for label in labels]`) lifts to
  native `<For each={labels}>{(label) => …}</For>` and renders three `<li>`,
- a view-shaped ternary (`<p> if show else <p>`) lifts to native
  `<Show when={show()} fallback={…}>`, and the `show` signal toggle proves the
  `<Show>` reactively swaps its arm.

As a `.cl.jac` the whole module is client codespace, so the bare `def:pub` runs
client-side (mirrors `solid_counter_app.cl.jac`).
"""

def:pub app() -> JsxElement {
    has show: bool = True;
    labels = ["alpha", "beta", "gamma"];

    return <div>
        <ul data-testid="list">
            {[<li key={label}>{label}</li> for label in labels]}
        </ul>
        <button data-testid="toggle" onClick={lambda e: any { show = not show; }}>
            toggle
        </button>
        {<p data-testid="shown">visible</p> if show else <p data-testid="hidden">hidden</p>}
    </div>;
}
