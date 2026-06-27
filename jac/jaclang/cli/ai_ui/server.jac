import from typing { Iterator }
import from jaclang.cli.ai_agent {
    ui_configure,
    ui_send,
    ui_poll,
    ui_graph,
    ui_reset,
    ui_stop,
    ui_stream,
    ui_settings,
    ui_apply_settings,
    ui_call_detail,
    ui_phase_context
}

with entry {
    ui_configure();
}


obj UiEvent {
    has id: int = 0,
        kind: str = "",
        text: str = "",
        name: str = "",
        node: str = "",
        tokens_in: int = 0,
        tokens_out: int = 0,
        cache_read: int = 0,
        cache_create: int = 0,
        ms: float = 0.0;
}


obj TurnStatsView {
    has elapsed: float = 0.0,
        tools: int = 0,
        reads: int = 0,
        writes: int = 0,
        runs: int = 0,
        files: int = 0,
        tokens_in: int = 0,
        tokens_out: int = 0,
        cost: float = 0.0,
        tok_per_s: float = 0.0,
        errors: int = 0,
        warnings: int = 0,
        health_loaded: bool = False,
        has_run: bool = False;
}

obj LedgerEntry {
    has phase: str = "",
        summary: str = "";
}

obj LedgerView {
    has changes: list[LedgerEntry] = [],
        notes: list[str] = [];
}


obj PollResult {
    has events: list[UiEvent] = [],
        status: str = "idle",
        active: str = "",
        path: list[str] = [],
        stats: TurnStatsView = TurnStatsView(),
        ledger: LedgerView = LedgerView(),
        needs_key: bool = False,
        key_env: str = "",
        model_name: str = "";
}


obj GraphNode {
    has id: str = "",
        label: str = "",
        desc: str = "",
        sem: str = "",
        tools: list[str] = [];
}

obj GraphEdge {
    has source: str = "",
        target: str = "";
}

obj GraphData {
    has nodes: list[GraphNode] = [],
        edges: list[GraphEdge] = [],
        state: PollResult = PollResult();
}

obj CallMessage {
    has role: str = "",
        content: str = "",
        tools: list[str] = [];
}

obj CallTool {
    has name: str = "",
        description: str = "",
        schema: str = "";
}


obj CallDetail {
    has found: bool = False,
        id: int = 0,
        node: str = "",
        input: list[CallMessage] = [],
        output: list[CallMessage] = [],
        shared: int = 0,
        total: int = 0,
        tokens_in: int = 0,
        tokens_out: int = 0,
        tools: list[CallTool] = [],
        tool_chars: int = 0,
        prev_id: int = -1,
        next_id: int = -1;
}

def _to_poll(snap: dict) -> PollResult {
    evs: list[UiEvent] = [];
    for e in snap.get("events", []) {
        evs.append(
            UiEvent(
                id=int(e.get("id", 0)),
                kind=str(e.get("kind", "")),
                text=str(e.get("text", "")),
                name=str(e.get("name", "")),
                node=str(e.get("node", "")),
                tokens_in=int(e.get("tokens_in", 0) or 0),
                tokens_out=int(e.get("tokens_out", 0) or 0),
                cache_read=int(e.get("cache_read", 0) or 0),
                cache_create=int(e.get("cache_create", 0) or 0),
                ms=float(e.get("ms", 0.0) or 0.0)
            )
        );
    }
    s = snap.get("stats", {});
    stats = TurnStatsView(
        elapsed=float(s.get("elapsed", 0.0) or 0.0),
        tools=int(s.get("tools", 0) or 0),
        reads=int(s.get("reads", 0) or 0),
        writes=int(s.get("writes", 0) or 0),
        runs=int(s.get("runs", 0) or 0),
        files=int(s.get("files", 0) or 0),
        tokens_in=int(s.get("tokens_in", 0) or 0),
        tokens_out=int(s.get("tokens_out", 0) or 0),
        cost=float(s.get("cost", 0.0) or 0.0),
        tok_per_s=float(s.get("tok_per_s", 0.0) or 0.0),
        errors=int(s.get("errors", 0) or 0),
        warnings=int(s.get("warnings", 0) or 0),
        health_loaded=bool(s.get("health_loaded", False)),
        has_run=bool(s.get("has_run", False))
    );
    led = snap.get("ledger", {}) or {};
    changes: list[LedgerEntry] = [];
    for c in led.get("changes", []) {
        changes.append(
            LedgerEntry(
                phase=str(c.get("phase", "")), summary=str(c.get("summary", ""))
            )
        );
    }
    ledger = LedgerView(changes=changes, notes=[str(n) for n in led.get("notes", [])]);
    return PollResult(
        events=evs,
        status=str(snap.get("status", "idle")),
        active=str(snap.get("active", "")),
        path=[str(p) for p in snap.get("path", [])],
        stats=stats,
        ledger=ledger,
        needs_key=bool(snap.get("needs_key", False)),
        key_env=str(snap.get("key_env", "")),
        model_name=str(snap.get("model_name", ""))
    );
}

def:pub agent_poll -> PollResult {
    return _to_poll(ui_poll());
}

def:pub agent_send(prompt: str) -> bool {
    return ui_send(prompt);
}

def:pub agent_graph -> GraphData {
    g = ui_graph();
    nodes: list[GraphNode] = [];
    for n in g.get("nodes", []) {
        nodes.append(
            GraphNode(
                id=str(n.get("id", "")),
                label=str(n.get("label", "")),
                desc=str(n.get("desc", "")),
                sem=str(n.get("sem", "")),
                tools=[str(t) for t in n.get("tools", [])]
            )
        );
    }
    edges: list[GraphEdge] = [];
    for ed in g.get("edges", []) {
        edges.append(
            GraphEdge(
                source=str(ed.get("source", "")), target=str(ed.get("target", ""))
            )
        );
    }
    return GraphData(nodes=nodes, edges=edges, state=_to_poll(g.get("state", {})));
}

def:pub agent_reset -> bool {
    ui_reset();
    return True;
}

def:pub agent_stop -> bool {
    ui_stop();
    return True;
}

def:pub agent_stream -> Iterator[dict] {
    return ui_stream();
}

def _to_call_msgs(raw: any) -> list[CallMessage] {
    out: list[CallMessage] = [];
    for m in raw {
        out.append(
            CallMessage(
                role=str(m.get("role", "")),
                content=str(m.get("content", "")),
                tools=[str(t) for t in m.get("tools", [])]
            )
        );
    }
    return out;
}

def _to_call_tools(raw: any) -> list[CallTool] {
    out: list[CallTool] = [];
    for t in raw {
        out.append(
            CallTool(
                name=str(t.get("name", "")),
                description=str(t.get("description", "")),
                schema=str(t.get("schema", ""))
            )
        );
    }
    return out;
}

def:pub agent_call_detail(call_id: int) -> CallDetail {
    d = ui_call_detail(call_id);
    if not d.get("found", False) {
        return CallDetail(found=False, id=call_id);
    }
    return CallDetail(
        found=True,
        id=call_id,
        node=str(d.get("node", "")),
        input=_to_call_msgs(d.get("input", [])),
        output=_to_call_msgs(d.get("output", [])),
        shared=int(d.get("shared", 0)),
        total=int(d.get("total", 0)),
        tokens_in=int(d.get("tokens_in", 0) or 0),
        tokens_out=int(d.get("tokens_out", 0) or 0),
        tools=_to_call_tools(d.get("tools", [])),
        tool_chars=int(d.get("tool_chars", 0) or 0),
        prev_id=int(d.get("prev_id", -1)),
        next_id=int(d.get("next_id", -1))
    );
}

obj PhaseContext {
    has found: bool = False,
        phase: str = "",
        messages: list[CallMessage] = [];
}

def:pub agent_phase_context(phase: str) -> PhaseContext {
    d = ui_phase_context(phase);
    return PhaseContext(
        found=bool(d.get("found", False)),
        phase=str(d.get("phase", phase)),
        messages=_to_call_msgs(d.get("messages", []))
    );
}

obj SettingsView {
    has model: str = "",
        api_key_set: bool = False,
        base_url: str = "",
        temperature: float = -1.0,
        n_ctx: int = 0,
        model_source: str = "",
        needs_key: bool = False,
        key_env: str = "",
        presets: list[str] = [];
}

obj SettingsResult {
    has ok: bool = False,
        error: str = "",
        model: str = "",
        needs_key: bool = False,
        key_env: str = "";
}

def:pub agent_settings -> SettingsView {
    s = ui_settings();
    return SettingsView(
        model=str(s.get("model", "")),
        api_key_set=bool(s.get("api_key_set", False)),
        base_url=str(s.get("base_url", "")),
        temperature=float(s.get("temperature", -1.0) or -1.0),
        n_ctx=int(s.get("n_ctx", 0) or 0),
        model_source=str(s.get("model_source", "")),
        needs_key=bool(s.get("needs_key", False)),
        key_env=str(s.get("key_env", "")),
        presets=[str(p) for p in s.get("presets", [])]
    );
}

def:pub agent_apply_settings(
    model: str, api_key: str, base_url: str, temperature: str, n_ctx: str
) -> SettingsResult {
    r = ui_apply_settings(model, api_key, base_url, temperature, n_ctx);
    return SettingsResult(
        ok=bool(r.get("ok", False)),
        error=str(r.get("error", "")),
        model=str(r.get("model", "")),
        needs_key=bool(r.get("needs_key", False)),
        key_env=str(r.get("key_env", ""))
    );
}
