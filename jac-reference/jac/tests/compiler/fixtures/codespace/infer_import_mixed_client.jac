"""Client consumer importing a mixed module in a single plain import.

One statement, two verdicts: the client symbol keeps its ES import (the
target module stays in the client bundle), while the server `def:pub`
bridges over RPC with no dead specifier.
"""

import from .infer_import_mixed_service { badge, count_items }

def:pub app -> JsxElement {
    has n: int = 0;

    can with entry {
        load();
    }

    async def load {
        n = await count_items();
    }

    return <div>{badge("total")}{n}</div>;
}
