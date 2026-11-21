"""Fixture: one free function's capability violation, sibling clean.

`pyonly` imports `collections` in its body; `clean` has no violation and
must stay natively lowered. Nothing native calls `pyonly`, so the module
keeps its LLVM IR with `pyonly` recorded as a seam.
"""

def clean(x: int) -> int {
    return x + 1;
}

def pyonly(x: int) -> int {
    import collections;
    d = collections.OrderedDict();
    return x + len(d);
}

with entry {
    print(clean(4));
}
