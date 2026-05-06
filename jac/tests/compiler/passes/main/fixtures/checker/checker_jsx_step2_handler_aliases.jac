"""Step 2: MouseEventHandler alias works as an annotation.
Passing wrong handler type should error."""

def IconButton(
    icon: str, onClick: MouseEventHandler
) -> JsxElement {
    return <button>{icon}</button>;
}

def good_handler(e: MouseEvent) -> None {}

def bad_handler(x: str) -> int {
    return 0;
}

with entry {
    # OK: correct handler matches MouseEventHandler = Callable[[MouseEvent], None]
    IconButton(icon="X", onClick=good_handler);

    # Error: (str) -> int is not Callable[[MouseEvent], None]
    IconButton(icon="X", onClick=bad_handler);
}
