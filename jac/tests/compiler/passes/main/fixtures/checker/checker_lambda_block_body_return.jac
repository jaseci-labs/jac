"""Lambda block-body return type inference.

Block-body lambdas (with curly braces) should infer their return type from
return statements, or default to None when no return statement is present.
This is critical for JSX event handlers like onClick={lambda e: MouseEvent { doStuff(); }}
which must match Callable[[MouseEvent], None]."""

def do_nothing() -> None {}
def get_number() -> int { return 42; }

# --- Cases that SHOULD pass (no errors) ---

# Case 1: Block lambda with no return statement → return type is None.
# Matches Callable[[MouseEvent], None] for onClick.
with entry {
    ok_void: Callable[[MouseEvent], None] = lambda e: MouseEvent { do_nothing(); };
}

# Case 2: Block lambda with bare return → return type is None.
with entry {
    ok_bare: Callable[[MouseEvent], None] = lambda e: MouseEvent { return; };
}

# Case 3: Block lambda with explicit return value → inferred from return expr.
with entry {
    ok_int: Callable[[MouseEvent], int] = lambda e: MouseEvent { return 42; };
}

# Case 4: Block lambda with assignment (no return) → None.
with entry {
    x = 0;
    ok_assign: Callable[[MouseEvent], None] = lambda e: MouseEvent { x = 1; };
}

# Case 5: Intrinsic JSX event handler with block lambda.
with entry {
    ok_jsx = <button onClick={lambda e: MouseEvent { do_nothing(); }}>Click</button>;
}

# Case 6: Mixed return — if branch returns int, else falls through.
# Inferred type should be int | None.
with entry {
    ok_mixed: Callable[[MouseEvent], int | None] = lambda e: MouseEvent {
        if True { return 42; }
    };
}

# --- Cases that SHOULD produce errors ---

# Case 7: Block lambda returns int but assigned to Callable[..., str] → type error.
with entry {
    bad_ret: Callable[[MouseEvent], str] = lambda e: MouseEvent { return 42; };
}
