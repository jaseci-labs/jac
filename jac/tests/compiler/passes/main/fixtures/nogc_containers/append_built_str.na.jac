"""Must fence (E1406): appending a freshly-built (owned heap) string."""
def run -> int {
    xs = [];
    i = 0;
    while i < 3 {
        xs.append("x" + str(i));
        i += 1;
    }
    return len(xs);
}

with entry {
    print(run());
}
