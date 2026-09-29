"""Fixture: a seam beside a native function that calls one module further down."""

import from jit_release_leaf { leaf_add }

def mid_seam(x: int) -> int {
    import collections;
    return x + len(collections.OrderedDict());
}

def mid_add(x: int) -> int {
    return leaf_add(x) + 1;
}
