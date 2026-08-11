"""Test: narrowing across loop-exit edges stays sound and precise.

A loop header's backward flow state is its loop-ENTRY state (back-edges are
skipped). Consumers on the loop's fall-through edge must therefore not
inherit that state when an iteration can rewrite the symbol -- the checker
has to fall back to the declared type there, so a later guard still narrows.
"""

def closure_loop_write(src: str) -> str {
    x: (str | None) = None;

    def fill {
        i = 0;
        while i < len(src) {
            x = src;
            i += 1;
        }
    }

    fill();
    if x is not None {
        return x;
    }
    return "";
}

def direct_loop_write(cond: bool) -> str {
    x: (str | None) = None;
    while cond {
        x = "value";
        cond = False;
    }
    if x is not None {
        return x;
    }
    return "";
}

def carry_across_loop(items: list[int], x: (str | None)) -> str {
    if x is not None {
        for i in items {
            items.append(i);
        }
        return x;
    }
    return "";
}

def loop_at_branch_tail(
    d: dict[str, int], ns: dict[str, dict[str, int]], x: (str | None)
) -> int {
    result: dict[str, int] = {};
    if x is not None {
        if x in ns {
            for (k, v) in ns[x].items() {
                result[k] = v;
            }
        }
        if x in d {
            return d[x];
        }
    }
    return 0;
}
