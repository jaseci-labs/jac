"""Rec 1.1 — for-loop slot with one child carrying an explicit `key=`.

Priority 1 of the auto-fragment key derivation: when one child in the
iteration body has an explicit `key=`, ViewLowerPass should LIFT that
key onto the synthesized `<React.Fragment>` wrapper and STRIP it from
the child. The iteration becomes one keyed unit; the child no longer
carries its own key.
"""

def:pub Card(item: str) -> JsxElement {
    return
        <article class="card">{item}</article>;
}

def:pub Footer(item: str) -> JsxElement {
    return
        <footer class="row-foot">{item} footer</footer>;
}

def:pub Mixed(items: list[str]) -> JsxElement {
    return
        <section class="feed">
            {for it in items {
                <Card key={it} item={it}/>
                <Footer item={it}/>
            }}
        </section>;
}
