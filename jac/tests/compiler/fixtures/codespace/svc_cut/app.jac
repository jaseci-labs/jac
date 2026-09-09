"""Markerless client consumer of a cross-app boundary import.

`backend` is a file-rooted service app that owns codespace_backend.jac, so the
import of it is a SERVICE_BRIDGE boundary fact (its target lives in another
app) while the import's own PLACEMENT is inferred: client code uses
`fetch_items`, so the import is placed client and becomes an RPC stub.
Meanwhile `local_report` also calls `fetch_items` but is referenced by no
client code - bridged names are callable from either side, so it stays server
and awaits the typed-async stub.
"""

import from .codespace_backend { fetch_items }

async def local_report -> int {
    return len(await fetch_items("all"));
}

async def:pub app -> JsxElement {
    items = await fetch_items("web");
    return <ul>{items}</ul>;
}
