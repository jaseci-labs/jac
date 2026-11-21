"""Step 5: Intrinsic HTML element prop type validation.
<button onClick={42}/> should produce a type error because onClick
on intrinsic elements expects MouseEventHandler."""

def handle_click(e: MouseEvent) -> None {}

with entry {
    # OK: correct handler on intrinsic element
    ok = <button onClick={handle_click}>Click</button>;

    # Error: int is not MouseEventHandler on intrinsic <button>
    bad = <button onClick={42}>Click</button>;
}
