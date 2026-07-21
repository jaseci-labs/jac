"""Scope-aware pulls: locals that shadow client names must not pull anything.

`server_side` mentions the names `clsx` and `styled`, but both resolve to its
own locals - symbol-based propagation produces no edge, so it stays server.
"""

import from "clsx" { clsx }

def styled -> str {
    return clsx(["x"]);
}

def server_side -> int {
    clsx = 5;
    styled = clsx + 1;
    return styled;
}
