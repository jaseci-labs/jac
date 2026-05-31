"""Live activity log: tool calls, results, phase moves, and reasoning.

Each tool call folds into a collapsible row -- the header (tool name + call)
always shows, and its output is a dropdown that is closed by default and
scrolls within itself when expanded. Consecutive reasoning ("thinking") tokens
fold into one dropdown that is open by default and streams in live. Everything
else renders as a terminal-style row. Auto-scrolls to the newest entry.
"""

import from react { useRef, useEffect }
sv import from ..server { UiEvent }

def:pub ActivityFeed(events: list[UiEvent], status: str) -> JsxElement {
    # Thinking blocks the user has collapsed (open by default). Tool outputs are
    # the opposite -- closed by default -- so they are tracked separately as the
    # ids the user has explicitly expanded.
    has collapsed: list[int] = [],
        expandedTools: list[int] = [];
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

    def toggleTool(bid: int) {
        if bid in expandedTools {
            expandedTools = [
                x
                for x in expandedTools
                if x != bid
            ];
        } else {
            expandedTools = expandedTools + [bid];
        }
    }

    # Fold the event stream into rows: consecutive reasoning into one think
    # block; each tool call into a tool row that its following tool_result fills.
    rows: list = [];
    block: any = None;
    toolRow: any = None;
    for e in events {
        if e.kind == "reasoning" {
            if block is None {
                block = {"id": e.id, "text": "", "live": False};
                rows.append({"type": "think", "id": e.id, "block": block});
            }
            block["text"] = block["text"] + e.text;
        } elif e.kind == "tool" {
            block = None;
            toolRow = {
                "id": e.id,
                "name": e.name,
                "call": e.text,
                "result": "",
                "done": False
            };
            rows.append({"type": "tool", "id": e.id, "row": toolRow});
        } elif e.kind == "tool_result" {
            block = None;
            # Attach the output to the tool call it belongs to (the most recent).
            if toolRow is not None {
                toolRow["result"] = e.text;
                toolRow["done"] = True;
            }
        } elif e.kind == "phase" or e.kind == "error" {
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
                                    else (
                                        <div className="evt tool toolrow" key={r["id"]}>
                                            <button
                                                className="tool-head"
                                                onClick={lambda { toggleTool(
                                                    r["id"]
                                                ); }}
                                            >
                                                <span className="chev">
                                                    {"▾"
                                                        if r["id"] in expandedTools
                                                        else "▸"}
                                                </span>
                                                <span className="tag">
                                                    {r["row"]["name"]}
                                                </span>
                                                <span className="body">
                                                    {r["row"]["call"]}
                                                </span>
                                                {<span className="think-dot live"/>
                                                    if not r["row"]["done"]
                                                    else <span className="think-count">
                                                        {str(len(r["row"]["result"])) + " chars"}
                                                    </span>}
                                            </button>
                                            {<div className="tool-body">
                                                {r["row"]["result"]
                                                    if r["row"]["result"]
                                                    else "(no output)"}
                                            </div>
                                                if r["id"] in expandedTools
                                                else None}
                                        </div>
                                            if r["type"] == "tool"
                                            else <div
                                                className={"evt " + r["ev"].kind}
                                                key={r["ev"].id}
                                            >
                                                <span className="tag">
                                                    {("→ " + r["ev"].node)
                                                        if r["ev"].kind == "phase"
                                                        else r["ev"].kind}
                                                </span>
                                                <span className="body">
                                                    {r["ev"].node
                                                        if r["ev"].kind == "phase"
                                                        else r["ev"].text}
                                                </span>
                                            </div>
                                    )
                            ) for r in rows
                        ]}
                        <div ref={endRef}/>
                    </div>}
            </div>
        </div>;
}
