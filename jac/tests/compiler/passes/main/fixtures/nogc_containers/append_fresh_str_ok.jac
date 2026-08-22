"""Move-in: freshly-built strings append into an owned list."""
def head(src: &str, n: int) -> own str {
    piece = src[0:n];
    return piece;
}

def run -> int {
    xs = [];
    i = 0;
    while i < 3 {
        xs.append(f"x{i}");
        i += 1;
    }
    xs.append("lit");
    xs.append("a" + str(7));
    xs.append(head(&"hello", 2));
    return len(xs);
}

with entry {
    print(run());
}
