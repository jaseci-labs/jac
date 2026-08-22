"""`extend` from a dict value, where the source arrives as a raw box.

A dict stores its values in an erased slot, so `for chunk in d.values()` hands
the loop an `i8*` even when the declared value type is a list. Every other
list method coerces its operand back to the slot type it wants before using
it; `extend` did not, and walked the box as if it were the list header --
which is a GEP into an `i8`, not a refusal.

The counts and the sums are both here on purpose: a handle that survives the
cast gives the right length even when the elements are unusable, so reading
each element back is what shows the source list was really found.
"""

def extend_str_lists(flag: bool) -> int {
    groups: dict[str, list[str]] = {"a": ["xx", "y"], "b": ["zzz"]};
    out: list[str] = [];
    if flag {
        for chunk in groups.values() {
            out.extend(chunk);
        }
    }
    total = 0;
    for s in out {
        total += len(s);
    }
    return total;
}


def count_str_lists(flag: bool) -> int {
    groups: dict[str, list[str]] = {"a": ["xx", "y"], "b": ["zzz"]};
    out: list[str] = [];
    if flag {
        for chunk in groups.values() {
            out.extend(chunk);
        }
    }
    return len(out);
}


def count_tuple_lists(flag: bool) -> int {
    groups: dict[int, list[tuple[(str, int)]]] = {
        1: [("a", 1), ("bb", 2)],
        2: [("ccc", 3)]
    };
    out: list[tuple[(str, int)]] = [];
    if flag {
        for chunk in groups.values() {
            out.extend(chunk);
        }
    }
    return len(out);
}


def extend_plain_list(flag: bool) -> int {
    src = [4, 5, 6];
    out: list[int] = [1];
    if flag {
        out.extend(src);
    }
    total = 0;
    for n in out {
        total += n;
    }
    return total;
}
