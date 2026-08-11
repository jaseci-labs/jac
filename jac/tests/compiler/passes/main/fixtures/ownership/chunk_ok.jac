"""chunked flow for: the licensed shape -- a lent chunks(n) collection,
per-chunk mutation through the view, reduction over the join."""

def scale(xs: &mut list[int]) -> int {
    flow for chunk in &mut xs.chunks(3) {
        for j in range(len(chunk)) {
            chunk[j] = chunk[j] * 2;
        }
    }
    t = 0;
    flow for c in &xs.chunks(4) {
        t += len(c);
    }
    return t;
}

glob ys: own list[int] = [1, 2, 3, 4, 5, 6, 7];

with entry {
    print(scale(&ys));
}
