"""Rec 7 — `has buttonRef: Ref[HTMLButtonElement];` lowers to useRef(null).

Ambient `Ref[T]` type. In client context, a `has`-field whose declared
type is `Ref[...]` lowers to `useRef(null)` instead of the usual
`useState(default)` — mirroring how `has count: int = 0;` already
lowers to `useState(0)`. The `useRef` symbol must be auto-imported from
react the same way `useState` is.

The JSX attribute `ref={buttonRef}` stays a pass-through to React's
built-in `ref` prop, which is how a `useRef` handle is wired to a DOM
node.
"""

def:pub FocusableButton(label: str) -> JsxElement {
    has buttonRef: Ref[HTMLButtonElement];

    def focus -> None {
        buttonRef.current.focus();
    }

    return
        <button ref={buttonRef} onClick={focus}>{label}</button>;
}
