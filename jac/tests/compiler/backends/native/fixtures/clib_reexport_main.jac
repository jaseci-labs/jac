"""Calls a C function imported through a re-exporting module."""

import from clib_reexport_mid { labs }

def magnitude(v: int) -> int {
    return labs(v);
}

with entry {
    print(magnitude(-42), labs(7));
}
