"""Fixture: a dependency whose seam function demotes while its sibling lowers.

`pyonly_len` imports `collections` in its body, the capability-partition
seam shape from #8206; `clean_add` has no violation and must stay natively
lowered. `xmod_demote_main.jac` calls both across the module boundary.
"""

def clean_add(x: int) -> int {
    return x + 1;
}

def pyonly_len(x: int) -> int {
    import collections;
    d = collections.OrderedDict();
    return x + len(d);
}

with entry {
    print(clean_add(4));
}
