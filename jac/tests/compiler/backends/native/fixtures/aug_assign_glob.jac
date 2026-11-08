"""List augmented assignment on module globals keeps the aliased list.

A global is a distinct lowering branch from a local (no slot overwrite), so
`+=`/`*=` must still mutate the list in place there.
"""

glob ITEMS: list[int] = [1, 2],
     NAMES: list[str] = ["a", "b"];

def glob_iadd_alias -> int {
    alias = ITEMS;
    ITEMS += [3];
    return len(ITEMS) * 100 + len(alias);
}

def glob_imul_alias -> int {
    alias = NAMES;
    NAMES *= 2;
    return len(NAMES) * 100 + len(alias);
}
