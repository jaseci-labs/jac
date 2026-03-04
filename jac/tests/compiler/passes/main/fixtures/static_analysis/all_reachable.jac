"""Test: all code is reachable, no unreachable warnings expected."""
def bar(x: int) -> str {
    if x > 0 {
        return "positive";
    } else {
        return "non-positive";
    }
}
