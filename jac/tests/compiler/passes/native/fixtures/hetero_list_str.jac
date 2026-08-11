"""A heap string stored into a heterogeneous list must survive read-back.

A list with mixed element types (e.g. `[int, str]`) lowers to a raw-integer
backing store, so a pointer element is boxed as an integer that the container
does not reference-count. If the source string is then freed at its last use
while the (escaping) list still holds it, the element becomes a dangling pointer
that the next allocation overwrites -- the string reads back as garbage or empty.

Each function builds a mixed list holding a heap-allocated string, then reads
that string back out and returns it, exercising the paths that regressed:
  - via_local:   a str local stored into the list by index assignment
  - via_literal: two heap slices placed directly in a mixed list literal
  - via_arg:     a str passed as an argument, stored, and returned
  - churn:       many mixed lists in a loop (rehash-scale), returns total length
"""

def via_local(s: str) -> str {
    cal: str = s[5:12];
    r: list = [19, ""];
    r[1] = cal;
    return r[1];
}


def via_literal_a(s: str) -> str {
    r: list = [99, s[0:3], s[5:12]];
    return r[1];
}


def via_literal_b(s: str) -> str {
    r: list = [99, s[0:3], s[5:12]];
    return r[2];
}


def via_arg(pos: int, tag: str) -> str {
    r: list = [pos, ""];
    r[1] = tag;
    return r[1];
}


def churn(n: int) -> int {
    total: int = 0;
    i: int = 0;
    while i < n {
        m: list = [i, "v" + str(i)];
        cc: str = m[1];
        total = total + len(cc);
        i = i + 1;
    }
    return total;
}
