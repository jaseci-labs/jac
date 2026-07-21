"""Markerless client consumer of an sv boundary import.

The `sv` marker on the import is a boundary fact (its target lives on the
server); the import's own PLACEMENT is inferred: client code uses
`fetch_items`, so the import is placed client and becomes an RPC stub.
Meanwhile `local_report` also calls `fetch_items` but is referenced by no
client code - sv-imported names are callable from either side, so it stays
server.
"""

sv import from .codespace_backend { fetch_items }

def local_report -> int {
    return len(fetch_items("all"));
}

def:pub app -> JsxElement {
    items = await fetch_items("web");
    return <ul>{items}</ul>;
}
