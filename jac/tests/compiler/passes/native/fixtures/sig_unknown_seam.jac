"""Fixture: one signature the backend cannot resolve, siblings clean.

`Peer` comes from a module the native lane refuses, so it never gets a native
struct and no signature naming it can lower. That failure lands while the
ability is declared -- before any body opens a demotion window -- which used
to cost the whole module its IR. `clean` and `Holder.also_clean` have nothing
wrong with them and must still lower.

`Holder.holds_peer` carries the same annotation and is the contrast: a method
signature erases a known-but-unlowerable type to an opaque pointer, so only
the free-function path ever refused here.
"""

import type from sig_unknown_peer { Peer }

def clean(x: int) -> int {
    return x + 1;
}

def takes_peer(p: Peer, x: int) -> int {
    return x + 1;
}

obj Holder {
    def also_clean(x: int) -> int {
        return x * 2;
    }

    def holds_peer(p: Peer, x: int) -> int {
        return x * 2;
    }
}

with entry {
    print(clean(4));
}
