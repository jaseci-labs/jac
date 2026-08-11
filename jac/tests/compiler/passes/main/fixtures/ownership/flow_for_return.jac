"""return inside a flow for body crosses the join: E1313."""

def first_even(xs: &list[int]) -> int {
    flow for v in &xs {
        if v % 2 == 0 {
            return v;
        }
    }
    return -1;
}
