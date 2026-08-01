"""Leaf of the glob-init ordering chain (issue #7593 item 11).

cval is runtime-initialized; its initializer must run before any dependent
module's glob initializer reads it through get_c().
"""

def:pub mk7() -> int {
    return 3 + 4;
}

glob cval: int = mk7();

def:pub get_c() -> int {
    return cval;
}
