"""Explicitly server-marked provider for the dead-client-import case.

The `.sv.jac` suffix pins the whole module server, so its accessless
helpers are never pulled by a client importer: they have no client-side
presence and no RPC bridge, which is exactly the E5082 case. (A markerless
module's accessless helpers would instead relocate via the cross-module
client pull.)
"""

def local_helper(n: int) -> str {
    return "item " + str(n);
}

def local_helper_two(n: int) -> str {
    return "row " + str(n);
}
