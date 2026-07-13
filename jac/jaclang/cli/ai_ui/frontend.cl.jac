"""Jac AI web UI -- top-level app: state, the live event stream, and the layout.

Loads the static phase graph once on mount, then opens an SSE stream
(`agent_stream`) and applies messages as they arrive -- a full snapshot first,
then one delta per bus emit. Reasoning and answer text stream in token by token
(each token re-pushes the growing event, which we upsert by id), so the UI
updates at token granularity rather than on a poll timer.
"""

import from react { useEffect, useRef }
sv import from .server {
    agent_send,
    agent_graph,
    agent_reset,
    agent_stop,
    agent_stream
}
sv import from .server {
    agent_settings,
    agent_apply_settings,
    agent_call_detail,
    agent_phase_context
}
sv import from .server { UiEvent, PollResult, GraphNode, GraphEdge, GraphData }
sv import from .server { CallDetail, PhaseContext }
import from .components.PhaseGraph { PhaseGraph }
import from .components.Conversation { Conversation }
import from .components.ActivityFeed { ActivityFeed }
import from .components.StatsBar { StatsBar }
import from .components.TokenStream { TokenStream }
import from .components.LedgerPane { LedgerPane }
import from .components.PhaseInspector { PhaseInspector }
import from .components.ResizeHandle { ResizeHandle }
import from .components.SettingsModal { SettingsModal }
import from .components.CallDetailModal { CallDetailModal }
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
        # The durable session ledger ({changes, notes}); refreshed whenever a
        # ledger message arrives so the bottom-pane panel mirrors it live.
        ledger: any = {"changes": [], "notes": []},
        # The graph node the user clicked, shown in the phase inspector, plus its
        # fetched context (the messages that phase last worked with).
        selected: str = "",
        phaseCtx: any = None,
        # The token-usage row (model call id) the user clicked, and its fetched
        # detail; -1 / None when the call-detail modal is closed.
        selectedCall: int = -1,
        callDetail: any = None,
        # Drag-resizable pane sizes (px): left column (conversation) width, right
        # column (activity) width, and bottom-pane height. The graph fills the
        # center column between them. The handles mutate these.
        leftW: int = 460,
        rightW: int = 380,
        bottomH: int = 200,
        draft: str = "",
        # Settings panel: open flag + the live key status the stream pushes in
        # every frame (so the panel auto-opens the moment a model needs a key).
        showSettings: bool = False,
        needsKey: bool = False,
        keyEnv: str = "",
        modelName: str = "",
        # Controlled settings-form fields, filled from `agent_settings` on open.
        sModel: str = "",
        sKey: str = "",
        sBaseUrl: str = "",
        sTemp: str = "",
        sNctx: str = "",
        sApiKeySet: bool = False,
        sPresets: list[str] = [],
        sModelSource: str = "",
        sError: str = "",
        sBusy: bool = False;

    unmountedRef: any = useRef(False);
    ctrlRef: any = useRef(None);
    # `window` typed loosely so viewport reads used to clamp pane sizes type-check
    # (the client stub omits that member).
    win: any = window;
    # The live event list is kept in a ref so the stream handler (captured once
    # by the effect) always upserts against the current list, not a stale render
    # closure -- otherwise each delta would rebuild from an empty `events`.
    eventsRef: any = useRef([]);
    # Held in a ref for the same reason as events: ledger messages are sparse, so
    # the handler must read the latest value, not a stale render closure.
    ledgerRef: any = useRef({"changes": [], "notes": []});
    # Last seen key-needed flag, so the panel auto-opens only on the rising edge
    # (false -> true): closing it without fixing the key won't immediately
    # reopen, but a fresh auth failure later will. A ref because the stream
    # handler is captured once (render state would be stale).
    needsKeyRef: any = useRef(False);

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
        # Ledger messages are sparse (only when a phase records or a note lands);
        # apply whenever present, otherwise keep the last value.
        if msg.ledger {
            ledgerRef.current = msg.ledger;
            ledger = msg.ledger;
        }
        status = msg.status;
        active = msg.active;
        path = msg.path;
        stats = msg.stats;
        # Key status rides along in every state frame. Auto-open the settings
        # panel on the rising edge of needs_key (incl. a mid-turn auth failure).
        needsKey = msg.needs_key;
        keyEnv = msg.key_env;
        modelName = msg.model_name;
        if msg.needs_key and not needsKeyRef.current {
            openSettings();
        }
        needsKeyRef.current = msg.needs_key;
    }

    # Fetch the current settings into the form fields, then open the panel.
    async def openSettings {
        s = await agent_settings();
        sModel = s.model;
        sBaseUrl = s.base_url;
        sTemp = "" if s.temperature < 0 else str(s.temperature);
        sNctx = "" if s.n_ctx == 0 else str(s.n_ctx);
        sApiKeySet = s.api_key_set;
        sPresets = s.presets;
        sModelSource = s.model_source;
        keyEnv = s.key_env;
        needsKey = s.needs_key;
        sKey = "";
        sError = "";
        showSettings = True;
    }

    # Apply the form. Temperature/context go as strings (blank = default); the
    # server parses, rebuilds the model, and pushes fresh state. On success the
    # panel closes; on failure it shows the error inline.
    async def applySettings {
        sBusy = True;
        sError = "";
        res = await agent_apply_settings(
            sModel.strip(), sKey, sBaseUrl.strip(), sTemp.strip(), sNctx.strip()
        );
        sBusy = False;
        needsKey = res.needs_key;
        keyEnv = res.key_env;
        if res.ok {
            modelName = res.model;
            showSettings = False;
        } else {
            sError = res.error;
        }
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
                Promise, lambda (resolve: any) { window.setTimeout(resolve, 800); }
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
        ledgerRef.current = {"changes": [], "notes": []};
        ledger = {"changes": [], "notes": []};
        selected = "";
        phaseCtx = None;
        selectedCall = -1;
        callDetail = None;
    }

    # Stop the running turn at the next checkpoint.
    async def stop {
        await agent_stop();
    }

    # Fetch and show one model call's detail (input/diff/output). Used by a
    # token-usage row click and the modal's Prev/Next; a negative id closes it.
    async def openCall(id: int) -> None {
        if id < 0 {
            selectedCall = -1;
            callDetail = None;
            return;
        }
        selectedCall = id;
        d = await agent_call_detail(id);
        callDetail = d;
    }

    # Fetch the clicked phase's captured context (its accumulated messages) for
    # the phase inspector; a blank id (deselect / reset) clears it.
    async def loadPhaseCtx(id: str) -> None {
        if not id {
            phaseCtx = None;
            return;
        }
        c = await agent_phase_context(id);
        phaseCtx = c;
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
        ledger = g.state.ledger;
        ledgerRef.current = g.state.ledger;
        needsKey = g.state.needs_key;
        keyEnv = g.state.key_env;
        modelName = g.state.model_name;
        if g.state.needs_key and not needsKeyRef.current {
            openSettings();
        }
        needsKeyRef.current = g.state.needs_key;
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
                <span className="meta">
                    {("agent control room" + (" · " + modelName if modelName else ""))}
                </span>
                <span className="spacer"/>
                <button className="btn ghost" onClick={lambda { reset(); }}>
                    New session
                </button>
                <button
                    className={"icon-btn attn" if needsKey else "icon-btn"}
                    title="Settings"
                    onClick={lambda { openSettings(); }}
                >
                    ⚙
                </button>
            </div>
            <div className="workspace">
                <div className="col left" style={{"width": str(leftW) + "px"}}>
                    <Conversation
                        {events}
                        {status}
                        {draft}
                        onDraftChange={lambda (v: str) { draft = v; }}
                        onSend={send}
                        onStop={stop}
                    />
                </div>
                <ResizeHandle
                    vertical={True}
                    onResize={lambda (dx: float) { leftW = max(
                        300, min(int(leftW + dx), int(win.innerWidth) - rightW - 320)
                    ); }}
                />
                <div className="col center">
                    <div className="pane">
                        <div className="pane-head">Phase graph</div>
                        <PhaseGraph
                            {nodes}
                            {edges}
                            {active}
                            {path}
                            {status}
                            {selected}
                            onSelect={lambda (id: str) {
                                selected = id;
                                loadPhaseCtx(id);
                            }}
                        />
                    </div>
                </div>
                <ResizeHandle
                    vertical={True}
                    onResize={lambda (dx: float) { rightW = max(
                        300, min(int(rightW - dx), int(win.innerWidth) - leftW - 320)
                    ); }}
                />
                <div className="col right" style={{"width": str(rightW) + "px"}}>
                    <ActivityFeed {events} {status}/>
                </div>
            </div>
            <ResizeHandle
                vertical={False}
                onResize={lambda (dy: float) { bottomH = max(
                    90, min(int(bottomH - dy), int(win.innerHeight) - 260)
                ); }}
            />
            <div className="bottompane" style={{"height": str(bottomH) + "px"}}>
                <TokenStream
                    events={events}
                    live={status == "running"}
                    selected={selectedCall}
                    onSelect={lambda (id: int) { openCall(id); }}
                />
                <LedgerPane {ledger}/>
                <PhaseInspector {nodes} {selected} context={phaseCtx}/>
            </div>
            <StatsBar {stats} {active}/>
            {<SettingsModal
                model={sModel}
                apiKeySet={sApiKeySet}
                keyDraft={sKey}
                baseUrl={sBaseUrl}
                temp={sTemp}
                nctx={sNctx}
                presets={sPresets}
                modelSource={sModelSource}
                needsKey={needsKey}
                keyEnv={keyEnv}
                error={sError}
                busy={sBusy}
                onModel={lambda (v: str) { sModel = v; }}
                onKey={lambda (v: str) { sKey = v; }}
                onBaseUrl={lambda (v: str) { sBaseUrl = v; }}
                onTemp={lambda (v: str) { sTemp = v; }}
                onNctx={lambda (v: str) { sNctx = v; }}
                onApply={applySettings}
                onClose={lambda { showSettings = False; }}
            />
                if showSettings
                else <span/>}
            {<CallDetailModal
                detail={callDetail}
                onPrev={lambda { openCall(int(callDetail.prev_id)); }}
                onNext={lambda { openCall(int(callDetail.next_id)); }}
                onClose={lambda { openCall(-1); }}
            />
                if (selectedCall >= 0 and callDetail)
                else <span/>}
        </div>;
}
