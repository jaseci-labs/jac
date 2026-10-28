impl ProcessGateway.setup {
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

impl ProcessGateway.serve(on_ready: any = None) {
    if self._gateway is None {
        self.setup();
    }
    gateway = self._gateway;
    assert gateway is not None , "setup() must bind the gateway";
    gateway.start(on_ready=on_ready);
}
