import from jac_scale.runtime.gateway.gateway { Gateway }
import from jac_scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jac_scale.runtime.gateway.service_registry { ServiceRegistry }
import from jac_scale.runtime.context.util {
    DEFAULT_GATEWAY_PORT,
    DEFAULT_GATEWAY_HOST,
    DEFAULT_CLIENT_DIST_DIR
}


obj ProcessGateway(Gateway) {
    has registry: ServiceRegistry,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        static_mounts: list[dict[str, str]] = [],
        _gateway: MicroserviceGateway | None = None;

    def setup {
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

    def serve {
        if self._gateway is None {
            self.setup();
        }
        self._gateway.start();
    }
}
