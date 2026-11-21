"""flow for requires a lent collection: iterating a plain name is E1313."""

glob xs = [1, 2];

with entry {
    flow for v in xs {
        print(v);
    }
}
