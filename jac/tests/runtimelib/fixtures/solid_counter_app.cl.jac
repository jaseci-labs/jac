"""Minimal Solid counter app for jsdom runtime verification.

The Solid analogue of `preact_counter_app.jac`: a `count` state field, a dynamic
`{count}` read, and an `onClick` handler that writes it. Under the Solid backend
the read lowers to an accessor thunk (`() => count()`) and the write to the
signal setter, so a click should reactively update the rendered text -- which is
what the jsdom harness in `test_solid_jsdom.jac` mounts and asserts. As a
`.cl.jac` the whole module is client codespace, so the bare `def:pub` runs
client-side (no `cl { }` wrapper needed).
"""

def:pub app() -> JsxElement {
    has count: int = 0;

    return <div>
        <p data-testid="count">Count: {count}</p>
        <button data-testid="inc" onClick={lambda (e: any) { count = count + 1; }}>
            +
        </button>
    </div>;
}
