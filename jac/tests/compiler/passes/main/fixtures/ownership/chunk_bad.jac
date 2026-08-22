"""chunks() is a for-collection form only, and chunk views are
fixed-extent: binding the call, calling it bare, or growing a chunk
each reject with E1313."""

def bad(xs: &mut list[int]) -> int {
    ys = xs.chunks(2);
    flow for c in &mut xs.chunks(2) {
        c.append(5);
    }
    return len(ys);
}
