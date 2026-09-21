"""Server endpoints reached only through the client's bridged import (Path B).

None of these are imported into the entry module. `cross_pub` / `cross_priv`
are called by the client component; `cross_orphan` is not called by anyone, but
exposure follows the declaration, so a `def:pub` is served whether or not any
caller references it.
"""

obj CrossView {
    has msg: str = "";
}

def:pub cross_pub -> CrossView {
    return CrossView(msg="pub-ok");
}

def:protect cross_priv -> CrossView {
    return CrossView(msg="priv-ok");
}

def:pub cross_orphan -> CrossView {
    return CrossView(msg="orphan");
}
