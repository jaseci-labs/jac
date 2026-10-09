"""Fixture: per-item handlers that each keep their own item (issue #8168).

A parameter is bound per call, a lambda-body local per invocation (#8130)
and the loop target per iteration, so none of these handlers shares a
binding with its siblings and none is reported.
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
