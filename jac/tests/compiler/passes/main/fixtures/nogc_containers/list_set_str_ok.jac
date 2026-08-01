"""Move-in: overwriting a list slot with a fresh str."""
def run -> int {
    xs = [f"a{0}"];
    xs[0] = f"b{1}";
    return len(xs);
}

with entry {
    print(run());
}
