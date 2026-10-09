"""Fixture: per-item handlers over a `for`-slot local (issue #8168).

A local assigned in a loop body belongs to the component, bare and
annotated alike, so the emitted `let` is hoisted to the component and
every handler the loop creates reads the last item. Both forms are E2097.
"""

def:pub Handlers(items: any, sink: Callable[[str], None]) -> JsxElement {
    def fire(text: str) {
        sink(text);
    }

    return
        <div>
            <div id="for_slot">
                {for s in items {
                    slotId = str(s.id);
                    <button onClick={lambda { fire("for_slot:" + slotId); }}>
                        {slotId}
                    </button>;
                }}
            </div>
            <div id="annotated">
                {for a in items {
                    annId: str = str(a.id);
                    <button onClick={lambda { fire("annotated:" + annId); }}>
                        {annId}
                    </button>;
                }}
            </div>
        </div>;
}
