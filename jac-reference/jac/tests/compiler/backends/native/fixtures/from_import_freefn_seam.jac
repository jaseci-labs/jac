"""Fixture: a `from`-import violation inside one free function, sibling clean.

`pyonly` names `collections.OrderedDict` through a body-scoped `from` import;
`clean` has no violation and must stay natively lowered. The partition that
decides fatal-versus-seam is the one #8206 established, so a `from`-import
item lands on the same side a bare import of the same module would.
"""

def clean(x: int) -> int {
    return x + 1;
}

def pyonly(x: int) -> int {
    import from collections { OrderedDict }
    d = OrderedDict();
    return x + len(d);
}

with entry {
    print(clean(4));
}
