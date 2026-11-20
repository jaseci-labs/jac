"""Step 6: Spread prop type checking.
Spreading a non-dict into a component's props should error."""

def Button(
    label: str, onClick: Callable[[MouseEvent], None],
    variant: str = "primary"
) -> JsxElement {
    return <button>{label}</button>;
}

with entry {
    # OK: dict spread is allowed
    props: dict[str, object] = {"label": "OK", "variant": "secondary"};
    ok = <Button {...props}/>;

    # Error: spreading an int (not a dict)
    bad_spread: int = 42;
    bad = <Button {...bad_spread}/>;
}
