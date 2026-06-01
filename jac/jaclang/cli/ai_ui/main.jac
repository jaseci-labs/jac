"""Jac AI web UI -- entry point combining the agent backend and the frontend.

This entry declares only the client app (`cl def:pub app` returns the React
tree, `cl import` pulls in the frontend). The server endpoints it calls are
registered automatically: the frontend's `sv import from .server` records the
client->server bindings the compiler resolves into live endpoints, so they no
longer need to be re-imported here under the server context.
"""

cl import from .frontend { app as ClientApp }

cl def:pub app -> JsxElement {
    return <ClientApp/>;
}
