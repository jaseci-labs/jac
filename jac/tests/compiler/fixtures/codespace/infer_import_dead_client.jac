"""Client consumer plainly importing pinned-server helpers (#7632).

The provider is explicitly server-marked (`.sv.jac`), so neither helper is
client-placed, cross-module pullable, or a `def:pub` endpoint: no
client-side artifact can satisfy this import. Each item must be its own
compile error (both share a source line, so the dedup must be
column-scoped), not a silently dead ES import that blanks the page at
module link time.
"""

import from .infer_import_dead_service { local_helper, local_helper_two }

def:pub app -> JsxElement {
    return <div>{local_helper(1)}{local_helper_two(2)}</div>;
}
