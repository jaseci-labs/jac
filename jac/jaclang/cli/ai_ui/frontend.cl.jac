"""Jac AI web UI -- top-level app: state, the poll loop, and the layout.

Fetches the phase graph once on mount, then polls the agent's event bus on a
timer (the bus is the source of truth for the conversation, the activity log,
the live walker position, and turn stats). The poll replaces all state wholesale
each tick, so the cytoscape graph and the chat stay in lockstep with the agent.
"""

import from react { useEffect }
sv import from .server { agent_poll, agent_send, agent_graph, agent_reset }
sv import from .server { UiEvent, PollResult, GraphNode, GraphEdge, GraphData }
import from .components.PhaseGraph { PhaseGraph }
import from .components.Conversation { Conversation }
import from .components.ActivityFeed { ActivityFeed }
import from .components.StatsBar { StatsBar }
import "./global.css";

def:pub app -> JsxElement {
    has events: list[UiEvent] = [],
        status: str = "idle",
        active: str = "",
        path: list[str] = [],
        nodes: list[GraphNode] = [],
        edges: list[GraphEdge] = [],
        draft: str = "";

    # Pull the latest event feed and walker position from the server. The RPC
    # stub is async, so the call must be awaited -- an un-awaited call leaves a
    # Promise in `res` and every field reads back undefined.
    async def refresh {
        res = await agent_poll();
        events = res.events;
        status = res.status;
        active = res.active;
        path = res.path;
    }

    # Kick off one turn; the poll loop then reflects its progress.
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
    }

    # First paint: load the static phase graph and the current state.
    async can with entry {
        g = await agent_graph();
        nodes = g.nodes;
        edges = g.edges;
        events = g.state.events;
        status = g.state.status;
        active = g.state.active;
        path = g.state.path;
    }

    # Poll the bus on a timer; clean up the interval on unmount.
    useEffect(
        lambda -> any {
            handle = window.setInterval(lambda { refresh(); }, 800);
            return lambda { window.clearInterval(handle); };
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
                    />
                </div>
                <div className="col right">
                    <div className="pane">
                        <div className="pane-head">Phase graph</div>
                        <PhaseGraph {nodes} {edges} {active} {path} {status}/>
                    </div>
                    <ActivityFeed {events}/>
                </div>
            </div>
            <StatsBar {events} {active}/>
        </div>;
}
