"""The Gateway port: front requests, run middleware, dispatch.

Two adapters implement it - EmbeddedGateway (in the app process, monolith) and
ProcessGateway (its own process/pod, microservice) - and are selected by the
realization plan. Both build their app, register the shared middleware chain, use
classify_route for dispatch, and serve. They differ only in hosting and in
whether a proxy hop is an in-process call or a network call; that difference is
carried by the ServiceTransport they are given, not by branching here.
"""

import from jac_scale.runtime.middleware.middleware { MiddlewareRegistry }


"""Abstract gateway contract."""
obj Gateway {
    has middleware: MiddlewareRegistry by postinit;

    def postinit -> None {
        self.middleware = MiddlewareRegistry();
    }

    """Build the serving app and register routes + middleware."""
    def setup -> None {
        raise NotImplementedError("setup() must be implemented by a Gateway");
    }

    """Start serving. Blocks for a process gateway; embeds into the host app for
    an embedded gateway."""
    def serve -> None {
        raise NotImplementedError("serve() must be implemented by a Gateway");
    }
}
