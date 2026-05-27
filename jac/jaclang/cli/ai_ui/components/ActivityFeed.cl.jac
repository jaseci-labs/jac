"""Live activity log: every tool call, result, reasoning chunk, and phase move.

The raw event stream the agent emits, rendered terminal-style. Auto-scrolls to
the newest event as the feed grows so the latest action stays in view.
"""

import from react { useRef, useEffect }
sv import from ..server { UiEvent }

def:pub ActivityFeed(events: list[UiEvent]) -> JsxElement {
    endRef: any = useRef(None);
    # Stick to the bottom as new events arrive. A useEffect callback must return
    # a cleanup function or nothing -- never an explicit None, which compiles to
    # `return null` and is then invoked as a (non-)function on teardown.
    useEffect(
        lambda { if endRef.current {
            endRef.current.scrollIntoView({"block": "end"});
        }},
        [len(events)]
    );
    rows = [
        e
        for e in events
        if e.kind == "tool"
        or e.kind == "tool_result"
        or e.kind == "phase"
        or e.kind == "reasoning"
        or e.kind == "error"
    ];
    return
        <div className="pane">
            <div className="pane-head">Activity</div>
            <div className="pane-body">
                {<div className="empty">No activity yet.</div>
                    if len(rows) == 0
                    else <div className="feed">
                        {[
                            <div className={"evt " + e.kind} key={e.id}>
                                <span className="tag">
                                    {("→ " + e.node)
                                        if e.kind == "phase"
                                        else (e.name if e.kind == "tool" else e.kind)}
                                </span>
                                <span className="body">
                                    {e.node if e.kind == "phase" else e.text}
                                </span>
                            </div> for e in rows
                        ]}
                        <div ref={endRef}/>
                    </div>}
            </div>
        </div>;
}
