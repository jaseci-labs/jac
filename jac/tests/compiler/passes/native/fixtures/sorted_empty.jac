"""Sorting a zero-length list is a no-op, not a wild read.

The native bubble sort computed `len - 1` in i64 and compared indices
against it unsigned, so an empty list wrapped the bound to 2^64 - 1 and
the first `get` walked off a zero-element backing store -- the process
died by SIGSEGV or abort depending on where the pointer landed. The
guard branches straight to done when `len <= 1`, which also covers the
single-element list the old loop handled only by accident of `0 >= 0`.

Reached through both spellings: `sorted(xs)` copies then sorts the
copy, and `xs.sort()` sorts in place; each entry point returns a length
or element the test can compare against CPython's answer.
"""

def sorted_empty_len() -> int {
    xs: list[str] = [];
    ys = sorted(xs);
    return len(ys);
}

def sort_empty_in_place_len() -> int {
    xs: list[int] = [];
    xs.sort();
    return len(xs);
}

def sorted_single_first() -> int {
    xs: list[int] = [7];
    ys = sorted(xs);
    return ys[0];
}

def sorted_pair_first() -> int {
    xs: list[int] = [9, 3];
    ys = sorted(xs);
    return ys[0];
}

def sorted_empty_from_compr() -> int {
    src: list[int] = [1, 2, 3];
    ys = sorted(
        [
            v
            for v in src
            if v > 100
        ]
    );
    return len(ys);
}
