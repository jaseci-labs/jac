"""Rec 1.3 — counted IterForStmt inside a JSX slot.

Priority 3 of the auto-fragment key derivation: when the loop is the
counted form (`for i = 0 to i < N by i += 1`), the synthesized
`<React.Fragment>` per iteration takes the counter variable as its key
— no jid() lookup, no lifted key.
"""

def:pub NumberedList -> JsxElement {
    return
        <ul class="numbered">
            {for i = 0 to i < 5 by i += 1 {
                <li>Row {i}</li>
                <hr/>
            }}
        </ul>;
}
