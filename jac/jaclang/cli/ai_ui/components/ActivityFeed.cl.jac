"""Live activity log: tool calls, results, phase moves, and reasoning.

Consecutive reasoning ("thinking") tokens fold into one collapsible dropdown
that streams its text in as the model generates it; everything else renders as
a terminal-style row. Auto-scrolls to the newest entry.
"""

import from react { useRef, useEffect }
sv import from ..server { UiEvent }

def:pub ActivityFeed(events: list[UiEvent], status: str) -> JsxElement {
    # Block ids the user has explicitly collapsed. Thinking blocks are open by
    # default so the tokens are visible as they stream.
    has collapsed: list[int] = [];
    endRef: any = useRef(None);
    useEffect(
        lambda { if endRef.current {
            endRef.current.scrollIntoView({"block": "end"});
        }},
        [len(events)]
    );

    def toggle(bid: int) {
        if bid in collapsed {
            collapsed = [
                x
                for x in collapsed
                if x != bid
            ];
        } else {
            collapsed = collapsed + [bid];
        }
    }

    # Fold consecutive reasoning events into one block; keep the rest as rows.
    rows: list = [];
    block: any = None;
    for e in events {
        if e.kind == "reasoning" {
            if block is None {
                block = {"id": e.id, "text": "", "live": False};
                rows.append({"type": "think", "id": e.id, "block": block});
            }
            block["text"] = block["text"] + e.text;
        } elif (
            e.kind == "tool"
            or e.kind == "tool_result"
            or e.kind == "phase"
            or e.kind == "error"
        ) {
            block = None;
            rows.append({"type": "evt", "ev": e});
        }
    }
    # The trailing thinking block is "live" while a turn is still running.
    if block is not None and status == "running" {
        block["live"] = True;
    }
    return
        <div className="pane">
            <div className="pane-head">Activity</div>
            <div className="pane-body">
                {<div className="empty">No activity yet.</div>
                    if len(rows) == 0
                    else <div className="feed">
                        {[
                            (
                                <div className="think" key={r["id"]}>
                                    <button
                                        className="think-head"
                                        onClick={lambda { toggle(r["id"]); }}
                                    >
                                        <span className="chev">
                                            {"▾" if r["id"] not in collapsed else "▸"}
                                        </span>
                                        <span className="think-label">
                                            {"thinking" + (
                                                "…" if r["block"]["live"] else ""
                                            )}
                                        </span>
                                        {<span className="think-dot live"/>
                                            if r["block"]["live"]
                                            else <span className="think-count">
                                                {str(len(r["block"]["text"])) + " chars"}
                                            </span>}
                                    </button>
                                    {<div className="think-body">
                                        {r["block"]["text"]}
                                    </div>
                                        if r["id"] not in collapsed
                                        else None}
                                </div>
                                    if r["type"] == "think"
                                    else <div
                                        className={"evt " + r["ev"].kind}
                                        key={r["ev"].id}
                                    >
                                        <span className="tag">
                                            {("→ " + r["ev"].node)
                                                if r["ev"].kind == "phase"
                                                else (
                                                    r["ev"].name
                                                        if r["ev"].kind == "tool"
                                                        else r["ev"].kind
                                                )}
                                        </span>
                                        <span className="body">
                                            {r["ev"].node
                                                if r["ev"].kind == "phase"
                                                else r["ev"].text}
                                        </span>
                                    </div>
                            ) for r in rows
                        ]}
                        <div ref={endRef}/>
                    </div>}
            </div>
        </div>;
}
