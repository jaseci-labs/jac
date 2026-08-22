"""nesting flow for is not supported yet: E1313."""

glob xs = [1, 2];

with entry {
    flow for v in &xs {
        ys = [v, v + 1];
        flow for w in &ys {
            print(w);
        }
    }
}
