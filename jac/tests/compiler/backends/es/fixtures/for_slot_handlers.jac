"""Fixture: per-item handlers built in `for` slots (issue #8168).

Every handler must act on its own item: the loop target, a local the slot
body assigns (bare or annotated), a `.map()` lambda-body local and a
parameter-bound factory alike.
"""

def:pub Handlers(items: any, sink: Callable[[str], None]) -> JsxElement {
    def fire(text: str) {
        sink(text);
    }

    def handlerFor(itemId: str) -> Callable[[], None] {
        return lambda { fire("factory:" + itemId); };
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
            <div id="factory">
                {for f in items {
                    facId = str(f.id);
                    <button onClick={handlerFor(facId)}>{facId}</button>;
                }}
            </div>
            <div id="map_lambda">
                {items.map(
                    lambda (m: any) -> JsxElement {
                        mapId = str(m.id);
                        return
                            <button onClick={lambda { fire("map_lambda:" + mapId); }}>
                                {mapId}
                            </button>;
                    }
                )}
            </div>
            <div id="loop_target">
                {for t in items {
                    <button onClick={lambda { fire("loop_target:" + str(t.id)); }}>
                        {str(t.id)}
                    </button>;
                }}
            </div>
        </div>;
}
