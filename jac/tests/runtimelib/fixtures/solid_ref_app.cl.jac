"""Solid ref end-to-end fixture (P2.2 jsdom matrix).

`has btnRef: Ref[HTMLButtonElement] = Ref()` lowers to `let btnRef = null`
on the Solid backend (contract §8 deferral). `babel-preset-solid` converts
`ref={btnRef}` to an assignment callback that runs after the element is
inserted, setting `btnRef` to the live DOM element.

The `check_ref` handler reads `btnRef` (truthy when the element is set) and
updates a reactive `refStatus` signal, which the harness queries to confirm
that the ref was populated. The test also proves that `ref={btnRef}` was
NOT wrapped in a view thunk (the compiler guard in test_acceptance_matrix
pins the string; this pins the runtime behaviour).
"""

def:pub app() -> JsxElement {
    has btnRef: Ref[HTMLButtonElement] = Ref();
    has refStatus: str = "unset";

    def check_ref(e: any) -> None {
        if btnRef {
            refStatus = "set";
        } else {
            refStatus = "null";
        }
    }

    return <div>
        <button ref={btnRef} data-testid="target">button</button>
        <button data-testid="check" onClick={check_ref}>check ref</button>
        <p data-testid="ref-status">{refStatus}</p>
    </div>;
}
