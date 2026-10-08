"""Fixture: per-item handlers built in a JSX `for` slot (issue #8168).

A local assigned in a loop body is owned by the enclosing component, so
every handler the loop creates over it shares one binding.

Errors (E2097), the handler is stored in the element: slotId, annId,
picked, sectionId, namedId, spreadId.

Warnings (W2084), the handler goes through a call first: wrappedId,
propsId.

Silent: a lambda-body local (mapId), a value bound through a parameter
(facId), the loop target (t), and a callback an array combinator runs
before the iteration ends (groupId).
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
            <div id="factory">
                {for f in items {
                    facId = str(f.id);
                    <button onClick={handlerFor(facId)}>{facId}</button>;
                }}
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

def:pub Rows(items: list[str], onPick: Callable[[str], None]) -> JsxElement {
    return
        <div>
            {for (i, item) in enumerate(items) {
                picked: str = item;
                <div key={str(i)} onClick={lambda { onPick(picked); }}>{item}</div>
            }}
        </div>;
}

def:pub Groups(
    groups: any, items: any, open: Callable[[str, str], None]
) -> JsxElement {
    return
        <div>
            {for g in groups {
                groupId = g.id;
                members = items.filter(
                    lambda (it: any) -> bool { return it.group == groupId; }
                );
                <p key={groupId}>{members.length}</p>;
            }}
            {for g in groups {
                sectionId = g.id;
                <ul key={sectionId}>
                    {[
                        <li onClick={lambda { open(sectionId, r.id); }}>{r.id}</li>
                        for r in g.rows
                    ]}
                </ul>;
            }}
        </div>;
}

def:pub Kept(items: any, pick: Callable[[str], None]) -> JsxElement {
    return
        <ul>
            {for it in items {
                namedId = str(it.id);
                def choose {
                    pick(namedId);
                }
                <li key={namedId} onClick={choose}>{namedId}</li>;
            }}
            {for it in items {
                spreadId = str(it.id);
                attrs = {"onClick": lambda { pick(spreadId); }};
                <li key={spreadId} {**attrs}>{spreadId}</li>;
            }}
        </ul>;
}

def:pub PassedOn(
    items: any,
    pick: Callable[[str], None],
    debounce: Callable[[Callable[[], None]], Callable[[], None]],
    row: Callable[[dict[str, any]], JsxElement]
) -> JsxElement {
    return
        <ul>
            {for it in items {
                wrappedId = str(it.id);
                <li key={wrappedId} onClick={debounce(lambda { pick(wrappedId); })}>
                    {wrappedId}
                </li>;
            }}
            {for it in items {
                propsId = str(it.id);
                cell = row({"onPick": lambda { pick(propsId); }});
                <li key={propsId}>{cell}</li>;
            }}
        </ul>;
}
