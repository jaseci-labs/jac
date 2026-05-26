"""Rec 7 — `has buttonRef: Ref[HTMLButtonElement] = Ref();` lowers to useRef(null).

Ambient `Ref[T]` type. In client context, a `has`-field whose declared
type is `Ref[...]` lowers to `useRef(...)` instead of the usual
`useState(default)` — mirroring how `has count: int = 0;` already
lowers to `useState(0)`. The field must be constructed explicitly:
`= Ref()` (empty DOM ref) lowers to `useRef(null)`, `= Ref(initial)`
lowers to `useRef(initial)`. The `useRef` symbol is auto-imported from
react.

The JSX attribute `ref={buttonRef}` stays a pass-through to React's
built-in `ref` prop, which is how a `useRef` handle is wired to a DOM
node.
"""

def:pub FocusableButton(label: str) -> JsxElement {
    has buttonRef: Ref[HTMLButtonElement] = Ref();

    def focus -> None {
        if buttonRef.current { buttonRef.current.focus(); }
    }

    return
        <button ref={buttonRef} onClick={focus}>{label}</button>;
}
