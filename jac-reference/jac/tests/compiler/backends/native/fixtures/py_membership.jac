"""String membership semantics (issue #7320 Cluster 2, item 2c).

`x in list[str]` and `k in d.keys()` must compare string values, not
pointer identity. Heap strings (concats) are used so equal values never
share a pointer; before the fix these tests were always False.
"""

def:pub str_list_membership -> int {
    labels = ["alpha", "be" + "ta", "gamma"];
    needle = "bet" + "a";
    a = 1 if "beta" in labels else 0;
    b = 1 if needle in labels else 0;
    c = 1 if "delta" in labels else 0;
    d = 1 if "delta" not in labels else 0;
    nums = [1, 2, 3];
    e = 1 if 2 in nums else 0;
    return a * 10000 + b * 1000 + c * 100 + d * 10 + e;
}

def:pub dict_keys_membership -> int {
    d: dict[str, int] = {};
    d["ka"] = 1;
    d["kb"] = 2;
    a = 1 if "kb" in d else 0;
    b = 1 if ("k" + "b") in d.keys() else 0;
    c = 1 if "kz" in d.keys() else 0;
    return a * 100 + b * 10 + c;
}

with entry {
    str_list_membership();
}
