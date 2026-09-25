obj ProcessGateway(Gateway) {
    has registry: ServiceRegistry,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        port_pinned: bool = False,
        _gateway: MicroserviceGateway | None = None;

    def setup {
        gw = MicroserviceGateway(
            registry=self.registry,
            port=self.port,
            host=self.host,
            client_dist_dir=self.client_dist_dir,
            port_pinned=self.port_pinned
        );
        gw.setup();
        self._gateway = gw;
    }

    def serve(on_ready: any = None) {
        if self._gateway is None {
            self.setup();
        }
        gateway = self._gateway;
        assert gateway is not None , "setup() must bind the gateway";
        gateway.start(on_ready=on_ready);
    }
}
