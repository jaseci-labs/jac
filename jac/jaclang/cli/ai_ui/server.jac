"""Server endpoints for the `jac ai --ui` web app.

Thin RPC surface over the agent's in-process event bus. This server runs in the
child `jac start` process the `--ui` launcher spawned; it re-imports the core
agent module, so its `agent` glob -- and the `agent.bus` the turn thread writes
to -- is the very object these endpoints read. `ui_configure()` runs once at
boot to point the agent at the user's project (passed via env by the launcher).
"""

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

# Point the agent at the user's project and build its model. Runs once when the
# server process imports this module at boot.
with entry {
    ui_configure();
}

"""One structured agent event for the UI feed (a flattened bus record).

`kind` is one of: system, user, reasoning, tool, tool_result, answer, phase,
status, stats, error. Only the fields a kind uses are populated; the rest stay
empty so the client can read any field unconditionally.
"""
obj UiEvent {
    has id: int = 0,
        kind: str = "",
        text: str = "",
        name: str = "",
        node: str = "",
        # Populated only for `call` events (one per model call): the token usage
        # the token-usage stream renders. Zero on every other kind.
        tokens_in: int = 0,
        tokens_out: int = 0,
        cache_read: int = 0,
        cache_create: int = 0,
        ms: float = 0.0;
}

"""The latest turn's summary stats -- the same set the CLI prints after a turn.

`has_run` is False until the first turn completes (the UI shows a placeholder
until then); `health_loaded` is False when the project model wasn't built this
turn, so the UI omits the health chip rather than claiming "clean".
"""
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

"""One recorded ledger step: which phase produced it and a one-line summary."""
obj LedgerEntry {
    has phase: str = "",
        summary: str = "";
}

"""The durable session ledger as the UI shows it: per-phase change entries plus
free-form notes. Mirrors the backend `Ledger` (changes + notes)."""
obj LedgerView {
    has changes: list[LedgerEntry] = [],
        notes: list[str] = [];
}

"""The per-tick poll payload: the event feed plus the live walker position.

`needs_key` is True when the active model still needs an API key the session
does not have; `key_env` names the missing provider var (e.g.
`ANTHROPIC_API_KEY`) and `model_name` the active model -- the client opens the
settings panel when `needs_key` flips True.
"""
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

"""A phase node in the agent's state graph (Plan/Build/QA/Done).

`desc` is the short blurb under the node; `sem` is the node's full role prompt
(its `_jac_semstr`) and `tools` the tool names it exposes -- both shown in the
UI's phase inspector when the node is clicked."""
obj GraphNode {
    has id: str = "",
        label: str = "",
        desc: str = "",
        sem: str = "",
        tools: list[str] = [];
}

"""A legal transition between two phase nodes."""
obj GraphEdge {
    has source: str = "",
        target: str = "";
}

"""The full phase graph plus the current walker state, for first paint."""
obj GraphData {
    has nodes: list[GraphNode] = [],
        edges: list[GraphEdge] = [],
        state: PollResult = PollResult();
}

"""One conversation message in a call's detail view: a role, its (truncated)
text, and one-line summaries of any tool calls it made."""
obj CallMessage {
    has role: str = "",
        content: str = "",
        tools: list[str] = [];
}

"""One tool available to the call: its name, description, and full JSON schema.
These ride the API's `tools` parameter (not the messages), so they are shown
separately in the detail view to account for the rest of `tokens_in`."""
obj CallTool {
    has name: str = "",
        description: str = "",
        schema: str = "";
}

"""The reconstructed detail for one token-usage row (model call).

`input` is the full conversation the call saw; `shared` is how many leading
messages it carried over unchanged from the previous call (the prompt-cached
prefix), so `input[shared:]` is the growth since then. `output` is what this
call produced (the assistant message plus any tool result), derived as the
forward diff to the next call. `prev_id`/`next_id` are the adjacent calls in
the same conversation for stepping (-1 when none). `found` is False for an
unknown id (e.g. evicted from the bounded store)."""
obj CallDetail {
    has found: bool = False,
        id: int = 0,
        node: str = "",
        input: list[CallMessage] = [],
        output: list[CallMessage] = [],
        shared: int = 0,
        total: int = 0,
        # The call's token counts (same as the row). `tokens_in` also covers the
        # tool JSON schemas, which the API sends separately and so are NOT among
        # the messages -- they are surfaced in `tools` so the counts reconcile.
        tokens_in: int = 0,
        tokens_out: int = 0,
        # The tool schemas sent with this call (the `tools` API param), and their
        # total character count for the modal's "~tokens" estimate.
        tools: list[CallTool] = [],
        tool_chars: int = 0,
        prev_id: int = -1,
        next_id: int = -1;
}

"""Map a raw bus snapshot dict into a typed PollResult for the client."""
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

"""Current event feed and walker state -- the client polls this on a timer."""
def:pub agent_poll -> PollResult {
    return _to_poll(ui_poll());
}

"""Kick off one agent turn for `prompt`; returns False if one is already running."""
def:pub agent_send(prompt: str) -> bool {
    return ui_send(prompt);
}

"""The phase graph (nodes + edges) plus current state, for the visualizer's mount."""
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

"""Clear the conversation, ledger, and event feed for a fresh session."""
def:pub agent_reset -> bool {
    ui_reset();
    return True;
}

"""Request that the running turn stop at the next checkpoint."""
def:pub agent_stop -> bool {
    ui_stop();
    return True;
}

"""Live event stream (SSE). Returning a generator makes the scale backend serve this as
`text/event-stream`, one `data: {json}` frame per bus emit -- so the client gets
reasoning/answer tokens as they are generated, plus phase/tool/status/stats
deltas. The client reads it with a fetch stream-reader (see frontend)."""
def:pub agent_stream -> Iterator[dict] {
    return ui_stream();
}

"""Map raw sanitized message dicts (role/content/tools) into typed CallMessages."""
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

"""Map raw tool-schema records (name/description/schema) into typed CallTools."""
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

"""Detail for one token-usage row: its full input conversation, the diff vs the
prior call, and its output. Fetched lazily when the user clicks a row, so the
heavy message text never rides the per-frame poll/stream."""
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

"""A phase node's captured context: the messages (role/content/tool-call
summaries) that phase last worked with. `found` is False for Done or before the
phase has run this session."""
obj PhaseContext {
    has found: bool = False,
        phase: str = "",
        messages: list[CallMessage] = [];
}

"""The latest captured conversation for a phase node (Plan/Build/QA), shown in
the phase inspector. Fetched lazily when the user clicks a graph node, so the
(potentially large) message text never rides the per-frame poll/stream."""
def:pub agent_phase_context(phase: str) -> PhaseContext {
    d = ui_phase_context(phase);
    return PhaseContext(
        found=bool(d.get("found", False)),
        phase=str(d.get("phase", phase)),
        messages=_to_call_msgs(d.get("messages", []))
    );
}

"""The settings panel's current values. `api_key_set` reports whether a key is
held without ever echoing it; `temperature` is -1 when unset (provider default);
`presets` are the quick-pick model names."""
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

"""The outcome of applying settings: `ok` plus the resulting model and key
status, or `ok=False` with an `error` message the panel shows inline."""
obj SettingsResult {
    has ok: bool = False,
        error: str = "",
        model: str = "",
        needs_key: bool = False,
        key_env: str = "";
}

"""Current settings for the panel's form (fetched when it opens)."""
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

"""Apply settings (model/key/base_url/temperature/context) and rebuild the model
live. `temperature`/`n_ctx` are strings (blank = default); a blank `api_key`
keeps the held one."""
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
