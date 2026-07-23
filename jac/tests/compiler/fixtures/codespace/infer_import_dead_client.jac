"""Client consumer plainly importing a server-only helper (#7632).

`local_helper` is neither client-placed nor a `def:pub` endpoint, so no
client-side artifact can satisfy this import: it must be a compile error,
not a silently dead ES import that blanks the page at module link time.
"""

import from .infer_import_bridge_service { local_helper }

def:pub app -> JsxElement {
    return <div>{local_helper(1)}</div>;
}
