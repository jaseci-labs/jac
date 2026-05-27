"""Jac AI web UI -- top-level app: state, the live event stream, and the layout.

Loads the static phase graph once on mount, then opens an SSE stream
(`agent_stream`) and applies messages as they arrive -- a full snapshot first,
then one delta per bus emit. Reasoning and answer text stream in token by token
(each token re-pushes the growing event, which we upsert by id), so the UI
updates at token granularity rather than on a poll timer.
"""

import from react { useEffect, useRef }
sv import from .server { agent_send, agent_graph, agent_reset, agent_stop }
sv import from .server { UiEvent, PollResult, GraphNode, GraphEdge, GraphData }
import from .components.PhaseGraph { PhaseGraph }
import from .components.Conversation { Conversation }
import from .components.ActivityFeed { ActivityFeed }
import from .components.StatsBar { StatsBar }
import from .components.TokenStream { TokenStream }
import "./global.css";

def:pub app -> JsxElement {
    has events: list[UiEvent] = [],
        status: str = "idle",
        active: str = "",
        path: list[str] = [],
        nodes: list[GraphNode] = [],
        edges: list[GraphEdge] = [],
        # Server-shaped TurnStatsView; the server constructs it, so the client
        # only ever holds a plain object (never instantiate the sv type here).
        stats: any = {"has_run": False},
        # Raw firehose of every streamed token, concatenated (capped).
        tokens: str = "",
        draft: str = "";

    unmountedRef: any = useRef(False);
    ctrlRef: any = useRef(None);
    # The live event list is kept in a ref so the stream handler (captured once
    # by the effect) always upserts against the current list, not a stale render
    # closure -- otherwise each delta would rebuild from an empty `events`. Same
    # reason for the token firehose buffer.
    eventsRef: any = useRef([]);
    tokensRef: any = useRef("");

    # Apply one stream message: a full snapshot replaces the feed; a delta
    # upserts the changed event by id (so a token re-push grows that event in
    # place). Both carry the current top-level state.
    def applyMsg(msg: any) -> None {
        if msg.heartbeat {
            return;
        }
        if msg.full {
            eventsRef.current = msg.events;
            events = msg.events;
        } elif msg.ev {
            ev = msg.ev;
            out = [];
            replaced = False;
            for e in eventsRef.current {
                if e.id == ev.id {
                    out.append(ev);
                    replaced = True;
                } else {
                    out.append(e);
                }
            }
            if not replaced {
                out.append(ev);
            }
            eventsRef.current = out;
            events = out;
        }
        # Firehose: append the raw token (delta msgs carry it; empty otherwise),
        # capped to the most recent stretch.
        if msg.token {
            nt = tokensRef.current + msg.token;
            if len(nt) > 4000 {
                nt = nt[len(nt) - 4000:];
            }
            tokensRef.current = nt;
            tokens = nt;
        }
        status = msg.status;
        active = msg.active;
        path = msg.path;
        stats = msg.stats;
    }

    # Read the SSE body frame by frame, parsing `data: {json}` messages.
    async def streamLoop {
        while not unmountedRef.current {
            ctrl = new(AbortController);
            ctrlRef.current = ctrl;
            try {
                token = window.localStorage.getItem("jac_token");
                headers = {"Content-Type": "application/json"};
                if token {
                    headers["Authorization"] = "Bearer " + token;
                }
                resp = await fetch(
                    "/function/agent_stream",
                    {
                        "method": "POST",
                        "headers": headers,
                        "body": "{}",
                        "signal": ctrl.signal
                    }
                );
                reader = resp.body.getReader();
                dec = new(TextDecoder);
                # Build newlines at runtime: a `"\n"` literal is double-escaped to
                # a literal backslash-n in the compiled client JS, so it would
                # never match the real newlines framing the SSE messages.
                nl = String.fromCharCode(10);
                sep = nl + nl;
                buf = "";
                while True {
                    chunk = await reader.read();
                    if chunk.done {
                        break;
                    }
                    buf = buf + dec.decode(chunk.value, {"stream": True});
                    parts = buf.split(sep);
                    buf = parts[len(parts) - 1];
                    i = 0;
                    while i < len(parts) - 1 {
                        data = "";
                        for line in parts[i].split(nl) {
                            if len(line) >= 5 and line[:5] == "data:" {
                                data = data + line[5:].strip();
                            }
                        }
                        if data {
                            try {
                                applyMsg(JSON.parse(data));
                            } except Exception { }
                        }
                        i += 1;
                    }
                }
            } except Exception { }
            if unmountedRef.current {
                break;
            }
            # Connection dropped (server restart, idle close) -- back off, reconnect.
            await new(
                Promise, lambda resolve: any { window.setTimeout(resolve, 800); }
            );
        }
    }

    async def send -> None {
        text = draft.strip();
        if not text {
            return;
        }
        draft = "";
        await agent_send(text);
    }

    async def reset {
        await agent_reset();
        events = [];
        active = "";
        path = [];
        stats = {"has_run": False};
        tokensRef.current = "";
        tokens = "";
    }

    # Stop the running turn at the next checkpoint.
    async def stop {
        await agent_stop();
    }

    # First paint: the static phase graph (nodes/edges the stream doesn't carry)
    # plus a quick snapshot of current state before the stream connects.
    async can with entry {
        g = await agent_graph();
        nodes = g.nodes;
        edges = g.edges;
        events = g.state.events;
        status = g.state.status;
        active = g.state.active;
        path = g.state.path;
        stats = g.state.stats;
    }

    # Open the live stream; abort it on unmount.
    useEffect(
        lambda -> any {
            unmountedRef.current = False;
            streamLoop();
            return lambda {
                unmountedRef.current = True;
                if ctrlRef.current {
                    ctrlRef.current.abort();
                }
            };
        },
        []
    );

    return
        <div className="app">
            <div className="topbar">
                <span className="brand">
                    jac
                    <span className="dot">●</span>
                    ai
                </span>
                <span className="meta">agent control room</span>
                <span className="spacer"/>
                <button className="btn ghost" onClick={lambda { reset(); }}>
                    New session
                </button>
            </div>
            <div className="workspace">
                <div className="col left">
                    <Conversation
                        {events}
                        {status}
                        {draft}
                        onDraftChange={lambda v: str { draft = v; }}
                        onSend={send}
                        onStop={stop}
                    />
                    <TokenStream text={tokens} live={status == "running"}/>
                </div>
                <div className="col right">
                    <div className="pane">
                        <div className="pane-head">Phase graph</div>
                        <PhaseGraph {nodes} {edges} {active} {path} {status}/>
                    </div>
                    <ActivityFeed {events} {status}/>
                </div>
            </div>
            <StatsBar {stats} {active}/>
        </div>;
}
