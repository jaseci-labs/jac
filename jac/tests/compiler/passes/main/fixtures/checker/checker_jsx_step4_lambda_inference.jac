"""Step 4: Bidirectional lambda param inference.
When onClick expects Callable[[MouseEvent], None], an untyped lambda e
should infer e as MouseEvent and allow e.clientX access."""

def Button(
    label: str, onClick: Callable[[MouseEvent], None]
) -> JsxElement {
    return <button>{label}</button>;
}

with entry {
    # OK: lambda e infers e: MouseEvent, clientX exists on MouseEvent
    ok = <Button label="OK" onClick={lambda e { e.clientX; }}/>;

    # Error: e is inferred as MouseEvent, which has no .nonexistent attribute
    bad = <Button label="Bad" onClick={lambda e { e.nonexistent; }}/>;
}
