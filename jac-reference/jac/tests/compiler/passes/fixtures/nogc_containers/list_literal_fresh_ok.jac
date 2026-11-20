"""Move/copy-in: a list literal of fresh, static, and named str elements."""
def run -> int {
    s = f"n{1}";
    xs = [f"a{0}", "lit", s];
    return len(xs) + len(s);
}

with entry {
    print(run());
}
