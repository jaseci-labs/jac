# Native fixture: first-class iterator values via iter() / next() and
# for-loop driving of a stored iterator.

# iter() + next(): explicit pull. a=5, b=7 -> 57
def iter_next_basic() -> int {
    it = iter([5, 7, 9]);
    a = next(it);
    b = next(it);
    return a * 10 + b;
}

# for-loop over a stored iterator value: 1+2+3+4 = 10
def for_over_iter() -> int {
    it = iter([1, 2, 3, 4]);
    total: int = 0;
    for x in it {
        total = total + x;
    }
    return total;
}

# iter() over a string, next() yields single-char strings; count first two.
# 'h','i' -> both length 1 -> 1 + 1 = 2
def str_iter_next() -> int {
    it = iter("hi");
    a = next(it);
    b = next(it);
    return len(a) + len(b);
}

with entry {}
