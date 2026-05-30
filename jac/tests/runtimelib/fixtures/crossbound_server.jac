"""Server endpoints reached only through the client's `sv import` (Path B).

None of these are imported into the entry module. `cross_pub` / `cross_priv`
are called by the client component; `cross_orphan` is not called by anyone, so
it must stay unregistered (Path B is scoped to real cross-boundary calls, not
"expose every pub").
"""

obj CrossView {
    has msg: str = "";
}

def:pub cross_pub -> CrossView {
    return CrossView(msg="pub-ok");
}

def:priv cross_priv -> CrossView {
    return CrossView(msg="priv-ok");
}

def:pub cross_orphan -> CrossView {
    return CrossView(msg="orphan");
}
