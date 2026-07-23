"""Mixed provider: one client-inferred declaration and one server endpoint.

`badge` seeds client (JSX), so a plain importer keeps a real ES import for
it; `count_items` is a server-placed `def:pub`, so the same import statement
must bridge it over RPC instead.
"""

def badge(label: str) -> JsxElement {
    return <span>{label}</span>;
}

def:pub count_items -> int {
    return 3;
}
