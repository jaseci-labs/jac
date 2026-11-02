impl ProcessGateway.setup {
    gw = MicroserviceGateway(
        registry=self.registry,
        port=self.port,
        host=self.host,
        client_dist_dir=self.client_dist_dir,
        static_mounts=self.static_mounts,
        port_pinned=self.port_pinned,
        base_path=str(self._resolve_base_path())
    );
    gw.setup();
    self._gateway = gw;
}

impl ProcessGateway._resolve_base_path -> Path {
    return resolve_base_path();
}

impl ProcessGateway.serve(on_ready: any = None) {
    if self._gateway is None {
        self.setup();
    }
    gateway = self._gateway;
    assert gateway is not None , "setup() must bind the gateway";
    gateway.start(on_ready=on_ready);
}
