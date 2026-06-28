"""Bug #SCOPE-1: annotated decl inside a loop body created a duplicate
symbol, breaking narrowing across if/elif branches.

Expected: 0 errors.
"""

def maybe_str() -> str | None {
    return None;
}

def test(items: list[int]) -> None {
    for it in items {
        result: str | None = None;
        if it > 0 {
            result = "hello";
        } elif it < 0 {
            result = maybe_str();
        }
    }
}
