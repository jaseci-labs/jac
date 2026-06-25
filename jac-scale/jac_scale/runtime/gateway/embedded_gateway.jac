"""EmbeddedGateway: the Gateway port adapter for the in-process realization.

This is the gateway that runs inside the app process - no second process, no
network hop. It fronts services that live in the same process and reaches each by
a direct call through an InProcessTransport, which is the monolith collapse of the
microservice blueprint: the same `/<svc>/function|walker/<name>` routes the
process gateway proxies over HTTP are served here by invoking the locally
registered callable. The realizer hands it an InProcessTransport whose handlers
the caller has registered for every in-process service member.

It shares the exact dispatch contract with the process gateway (classify_route +
member-subpath routing, SPA fallback for everything else) so a request behaves
identically whether the topology is collapsed in-process or fanned out across
pods - that is the "works local => works cloud" guarantee made structural.

Scope: handles the function/walker call surface (the SPA's apiCall pattern) and
the static/SPA fallback. Builtins exposed only by a full service pod (per-service
/openapi.json aggregation, etc.) are the process gateway's concern.
"""

import logging;
import mimetypes;
import from pathlib { Path }
import from fastapi { FastAPI, Request }
import from fastapi.responses { JSONResponse, Response }
import from jac_scale.runtime.gateway.gateway { Gateway }
import from jac_scale.runtime.gateway.service_registry { ServiceRegistry }
import from jac_scale.runtime.gateway.dispatch {
    classify_route,
    ROUTE_PROXY,
    ROUTE_STATIC
}
import from jac_scale.runtime.transport.transport { ServiceTransport }
import from jac_scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}

glob _logger = logging.getLogger(__name__);


"""In-process gateway. `registry` carries the service routing table; `transport`
is the InProcessTransport holding the locally-registered service member callables.
"""
obj EmbeddedGateway(Gateway) {
    has registry: ServiceRegistry,
        transport: ServiceTransport,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        app: FastAPI | None = None;

    """Build the in-process FastAPI app: shared middleware chain + the
    classify_route dispatcher."""
    def setup -> None;

    """The list of registered service prefixes, for classify_route."""
    def _service_prefixes -> list[str];

    """The service name owning a matched prefix (transport keys are by name)."""
    def _service_for_prefix(prefix: str) -> str;

    """Dispatch one request: member subpath -> in-process transport call, else
    static/SPA. Pure-ish (depends on the transport + registry), so it is unit
    testable without binding a socket."""
    async def dispatch(request: Request) -> Response;

    """Invoke the service member named in `remainder` (`/function/<name>` or
    `/walker/<name>`) through the in-process transport. Returns None when the
    remainder is not a function/walker member, so the caller can fall to static."""
    async def _call_member(
        service: str, remainder: str, payload: dict[str, any]
    ) -> Response | None;

    """Serve a static asset or the SPA index.html fallback. Returns a 404 JSON
    envelope when neither exists."""
    def _serve_static(path: str, accept: str) -> Response;

    """Start serving in-process (blocks on uvicorn)."""
    def serve -> None;
}
