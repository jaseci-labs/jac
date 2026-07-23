"""Client consumer plainly importing server-only helpers (#7632).

Neither helper is client-placed or a `def:pub` endpoint, so no client-side
artifact can satisfy this import: each item must be its own compile error
(both share a source line, so the dedup must be column-scoped), not a
silently dead ES import that blanks the page at module link time.
"""

import from .infer_import_bridge_service { local_helper, local_helper_two }

def:pub app -> JsxElement {
    return <div>{local_helper(1)}{local_helper_two(2)}</div>;
}
