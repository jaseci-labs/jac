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
    ui_stream
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
        node: str = "";
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

"""The per-tick poll payload: the event feed plus the live walker position."""
obj PollResult {
    has events: list[UiEvent] = [],
        status: str = "idle",
        active: str = "",
        path: list[str] = [],
        stats: TurnStatsView = TurnStatsView();
}

"""A phase node in the agent's state graph (Plan/Build/QA/Done)."""
obj GraphNode {
    has id: str = "",
        label: str = "",
        desc: str = "";
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
                node=str(e.get("node", ""))
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
    return PollResult(
        events=evs,
        status=str(snap.get("status", "idle")),
        active=str(snap.get("active", "")),
        path=[str(p) for p in snap.get("path", [])],
        stats=stats
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
                desc=str(n.get("desc", ""))
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

"""Live event stream (SSE). Returning a generator makes jac-scale serve this as
`text/event-stream`, one `data: {json}` frame per bus emit -- so the client gets
reasoning/answer tokens as they are generated, plus phase/tool/status/stats
deltas. The client reads it with a fetch stream-reader (see frontend)."""
def:pub agent_stream -> Iterator[dict] {
    return ui_stream();
}
