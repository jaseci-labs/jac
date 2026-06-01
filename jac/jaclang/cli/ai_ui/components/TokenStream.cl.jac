"""Live token-usage stream: one row per model call, newest last, showing the
tokens that went into and came out of each call -- input (with a magnitude bar
so an oversized prompt stands out), output, cache read/created, and latency,
tagged by the phase it belongs to (or "route" for the routing decision). Makes
context-size spikes and cache (re)use visible as the agent works. Clicking a row
opens its detail (full input, the diff vs the prior call, and the output).
"""

import from react { useRef, useEffect }
sv import from ..server { UiEvent }

"""Compact a token count: 66711 -> "66k", 940 -> "940"."""
def _k(n: int) -> str {
    return (str(n // 1000) + "k") if n >= 1000 else str(n);
}

def:pub TokenStream(
    events: list[UiEvent], live: bool, selected: int, onSelect: Callable[[int], None]
) -> JsxElement {
    endRef: any = useRef(None);
    calls = [
        e
        for e in events
        if e.kind == "call"
    ];
    # Scale the input bars against the largest call this turn so the worst
    # offender (e.g. the routing call) fills the row.
    maxIn = 1;
    for e in calls {
        if e.tokens_in > maxIn {
            maxIn = e.tokens_in;
        }
    }
    useEffect(
        lambda { if endRef.current {
            endRef.current.scrollIntoView({"block": "end"});
        }},
        [len(calls)]
    );
    return
        <div className="bp-section tokenstream">
            <div className="pane-head">
                token usage
                <span className="spacer"/>
                {<span className="think-dot live"/> if live else <span/>}
            </div>
            <div className="bp-body tokusage-body">
                {<div className="empty">
                    per-call tokens appear here as the model runs…
                </div>
                    if len(calls) == 0
                    else <div className="tokfeed">
                        {[
                            (
                                <div
                                    className={"tokrow clickable" + (
                                        " sel" if e.id == selected else ""
                                    )}
                                    key={e.id}
                                    onClick={lambda { onSelect(e.id); }}
                                >
                                    <span className={"tok-chip tok-" + e.node}>
                                        {e.node}
                                    </span>
                                    <div className="tok-inwrap">
                                        <div
                                            className="tokbar"
                                            style={{
                                                "width": str(
                                                    int(e.tokens_in * 100 / maxIn)
                                                ) + "%"
                                            }}
                                        />
                                        <span className="tok-in">
                                            {_k(e.tokens_in) + " in"}
                                        </span>
                                    </div>
                                    <span className="tok-out">
                                        {_k(e.tokens_out) + " out"}
                                    </span>
                                    <span
                                        className="tok-cache"
                                        title="cache read / created"
                                    >
                                        {"⟳" + _k(e.cache_read) + " +" + _k(
                                            e.cache_create
                                        )}
                                    </span>
                                    <span className="tok-ms">
                                        {(str(int(e.ms)) + "ms") if e.ms > 0 else ""}
                                    </span>
                                </div>
                            ) for e in calls
                        ]}
                        <div ref={endRef}/>
                    </div>}
            </div>
        </div>;
}
