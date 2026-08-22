"""Client consumer of a server module through a plain import.

The `sv` marker is a boundary fact the compiler can infer here: the target
declaration is a server-placed `def:pub`, so the import must lower to an
RPC stub - never to an ES import of a module that has no client exports
(#7632).
"""

import from .infer_import_bridge_service { fetch_msg }

def:pub app -> JsxElement {
    has msg: str = "";

    can with entry {
        load();
    }

    async def load {
        msg = await fetch_msg("web");
    }

    return <div>{msg}</div>;
}
