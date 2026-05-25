"""Value ref -- `has n: Ref[int] = Ref(0);` lowers to `useRef(0)`.

The other useRef shape: a mutable value that persists across renders
without triggering one. `Ref(initial)` seeds `.current`; the seed is
lifted into `useRef(initial)`.
"""

def:pub Counter() -> JsxElement {
    has renderCount: Ref[int] = Ref(0);

    def bump -> None {
        renderCount.current = (renderCount.current or 0) + 1;
    }
    return <button onClick={bump}>bump</button>;
}
