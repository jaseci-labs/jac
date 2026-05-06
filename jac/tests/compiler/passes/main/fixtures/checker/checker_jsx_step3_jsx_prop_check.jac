"""Step 3: JSX attribute type checking against component parameters.
<Button onClick={42}/> should produce a type error."""

def Button(
    label: str, onClick: Callable[[MouseEvent], None],
    variant: str = "primary", disabled: bool = False
) -> JsxElement {
    return <button>{label}</button>;
}

def handle_click(e: MouseEvent) -> None {}

with entry {
    # OK: correct props via JSX
    x = <Button label="OK" onClick={handle_click}/>;

    # Error: int is not Callable[[MouseEvent], None] via JSX prop
    y = <Button label="Bad" onClick={42}/>;
}
