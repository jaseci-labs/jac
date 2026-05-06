"""Step 1: onClick annotation uses Callable[[MouseEvent], None] instead of any.
Passing a non-callable (int) to onClick via function-call style should error."""

def Button(
    label: str, onClick: Callable[[MouseEvent], None],
    variant: str = "primary", disabled: bool = False
) -> JsxElement {
    return <button>{label}</button>;
}

def handle_click(e: MouseEvent) -> None {}

with entry {
    # OK: correct handler
    Button(label="OK", onClick=handle_click);

    # Error: int is not Callable[[MouseEvent], None]
    Button(label="Bad", onClick=42);
}
