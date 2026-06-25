"""ProcessGateway: the Gateway port adapter for the out-of-process (microservice)
realization.

This is the gateway that runs in its own process or pod and fronts a fleet of
service processes, reaching each over the network. It is the planner's choice for
the `process` gateway_mode. The actual request handling (admin endpoints, the
classify_route dispatcher, the reverse proxy, static/SPA fallback) lives in
MicroserviceGateway, which this adapter owns and drives; ProcessGateway exists so
the realizer constructs and serves every cell through the one Gateway port rather
than reaching for a concrete gateway by name.

A process gateway's proxy hop is a raw HTTP forward (arbitrary path/method/body to
the matched service), not a semantic sv-call, so it does not carry a
ServiceTransport - that port is the EmbeddedGateway's, whose hops are in-process.
"""

import from jac_scale.runtime.gateway.gateway { Gateway }
import from jac_scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jac_scale.runtime.gateway.service_registry { ServiceRegistry }
import from jac_scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}


"""Out-of-process gateway: owns a MicroserviceGateway and serves it. `registry`
carries the service routing table the planner/orchestrator built."""
obj ProcessGateway(Gateway) {
    has registry: ServiceRegistry,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        static_mounts: list[dict[str, str]] = [],
        _gateway: MicroserviceGateway | None = None;

    """Build the underlying MicroserviceGateway and its FastAPI app."""
    def setup -> None {
        gw = MicroserviceGateway(
            registry=self.registry,
            port=self.port,
            host=self.host,
            client_dist_dir=self.client_dist_dir,
            static_mounts=self.static_mounts
        );
        gw.setup();
        self._gateway = gw;
    }

    """Start serving (blocks on uvicorn). Sets up lazily if not already."""
    def serve -> None {
        if self._gateway is None {
            self.setup();
        }
        self._gateway.start();
    }
}
