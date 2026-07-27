"""Entry module that opens the client app but deliberately does NOT import any
server endpoint. The endpoints are reached only through the client's
`sv import`, so they exercise Path B (whole-program cross-boundary detection).
"""

cl {
    import from .crossbound_frontend { Panel as ClientPanel }

    def:pub app -> JsxElement {
        return <ClientPanel/>;
    }
}
