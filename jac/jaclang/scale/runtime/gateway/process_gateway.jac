import from pathlib { Path }


obj ProcessGateway(Gateway) {
    has registry: ServiceRegistry,
        port: int = DEFAULT_GATEWAY_PORT,
        host: str = DEFAULT_GATEWAY_HOST,
        client_dist_dir: str = DEFAULT_CLIENT_DIST_DIR,
        static_mounts: list[dict[str, str]] = [],
        port_pinned: bool = False,
        _gateway: MicroserviceGateway | None = None;

    def setup;
    def _resolve_base_path -> Path;
    def serve(on_ready: any = None);
}
