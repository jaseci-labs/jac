"""Incoherent bare ref field -- must be constructed (E2025).

`has r: Ref[T];` with no `= Ref()` construction has no ref object to
hold; it is rejected by E2025 directing the author to `= Ref()`.
"""

def:pub Bad() -> JsxElement {
    has r: Ref[HTMLInputElement];
    return <input ref={r} />;
}
