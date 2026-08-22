"""Copy-in: a named owned string appends by copy; the source stays live."""
def run -> int {
    xs = [];
    s = f"v{1}";
    xs.append(s);
    print(s);
    return len(xs);
}

with entry {
    print(run());
}
