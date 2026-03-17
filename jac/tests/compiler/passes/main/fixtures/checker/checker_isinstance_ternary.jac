"""Tests for isinstance type narrowing in ternary expressions."""

class Node {}

def test_ternary_narrowing(left: Node | list[Node]) -> list[Node] {
    # isinstance should narrow `left` to Node in true branch
    # and to list[Node] in else branch
    result = [left] if isinstance(left, Node) else left;
    return result;
}

def test_ternary_narrowing_simple(x: int | str) -> list[int] | str {
    return [x] if isinstance(x, int) else x;
}

# Test with None type
def test_ternary_none(val: str | None) -> str {
    return val if val is not None else "default";
}

# Test nested ternary
def test_nested_ternary(x: int | str | None) -> str {
    return str(x) if isinstance(x, int) else (x if x is not None else "none");
}
