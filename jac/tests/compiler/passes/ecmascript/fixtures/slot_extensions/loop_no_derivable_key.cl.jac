"""Rec 1.4 — for-loop slot with no auto-derivable key.

Priority 4 (the W2021 fallback) of the auto-fragment key derivation:
the loop var is `str` (not a Jac obj or node, so jid() doesn't apply),
the loop is in-for (not counted), and no child carries an explicit
`key=`. None of priorities 1-3 fire, so ViewLowerPass must emit W2021
asking the author to annotate one child with `key=`.
"""

def:pub Boxes(items: list[str]) -> JsxElement {
    return
        <section class="boxes">
            {for s in items {
                <h3>{s}</h3>
                <p>more about {s}</p>
            }}
        </section>;
}
