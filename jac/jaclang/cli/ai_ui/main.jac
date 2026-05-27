"""Jac AI web UI -- entry point combining the agent backend and the frontend.

Server is the default context, so the endpoint + type imports sit plainly at the
top (this is what registers them, and how the access-extraction pass sees their
`def:pub` visibility); the client app is opened under the `to cl:` section.
"""

import from server {
    agent_poll,
    agent_send,
    agent_graph,
    agent_reset,
    agent_stop,
    agent_stream
}
import from server {
    UiEvent,
    PollResult,
    TurnStatsView,
    GraphNode,
    GraphEdge,
    GraphData
}

to cl:

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    return
        <ClientApp/>;
}
