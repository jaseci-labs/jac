"""Mixed provider: one client-inferred declaration and one server endpoint.

`badge` seeds client (JSX), so a plain importer keeps a real ES import for
it; `count_items` is a `def:pub` in a server-anchored module (the os import
anchors it), so the same import statement must bridge it over RPC instead.
"""
import os;

def badge(label: str) -> JsxElement {
    return <span>{label}</span>;
}

def:pub count_items -> int {
    return len(os.environ) - len(os.environ);
}
