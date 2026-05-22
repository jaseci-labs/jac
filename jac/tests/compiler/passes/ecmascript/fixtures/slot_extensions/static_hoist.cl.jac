"""Rec 4 — static JSX subtree closing only over module-level bindings.

The `<footer>` subtree references only the module-level `BRAND` and
`YEAR` globals, no `has`-fields, no params, no slot locals. A static
hoisting analysis can lift this subtree to a module-level const so the
React renderer reuses one element identity across every render of
`Page` instead of reconstructing it on every call.
"""

glob BRAND: str = "Jac",
     YEAR: int = 2026;

def:pub Page(title: str) -> JsxElement {
    return
        <main>
            <h1>{title}</h1>
            <footer>
                <span class="brand">{BRAND}</span>
                <span class="year">{YEAR}</span>
            </footer>
        </main>;
}
