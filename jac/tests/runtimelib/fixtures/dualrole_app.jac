"""Entry module for the cl->sv dual-role scenario (#6507).

Opens the client app only; it imports no server endpoint directly. The
guestbook endpoints are reached purely through the client's `sv import`
(the cl->sv load path), and the guestbook module is *itself* a server->server
consumer of the analytics service.
"""

cl {
    import from .dualrole_frontend { Panel as ClientPanel }

    def:pub app -> JsxElement {
        return <ClientPanel/>;
    }
}
