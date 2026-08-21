import from pathlib { Path }
import from jaclang.scale.runtime.gateway.gateway { Gateway }
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry { ServiceRegistry }
import from jaclang.scale.runtime.context.util {
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
            static_mounts=self.static_mounts,
            base_path=str(self._resolve_base_path())
        );
        gw.setup();
        self._gateway = gw;
    }

    def _resolve_base_path -> Path {
        import from jaclang.project.config { resolve_base_path }

        return resolve_base_path();
    }

    def serve {
        if self._gateway is None {
            self.setup();
        }
        self._gateway.start();
    }
}
