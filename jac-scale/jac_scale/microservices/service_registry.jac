import from datetime { datetime }

enum ServiceStatus {
    REGISTERED = "registered",
    STARTING = "starting",
    HEALTHY = "healthy",
    UNHEALTHY = "unhealthy",
    STOPPED = "stopped"
}

obj ServiceEntry {
    has name: str,
        file: str,
        prefix: str,
        port: int = 0,
        replicas: int = 1,
        env: dict[str, str] = {},
        url: str = "",
        pid: int | None = None,
        status: ServiceStatus = ServiceStatus.REGISTERED,
        last_health_check: datetime | None = None;
}

obj ServiceRegistry {
    has entries: dict[str, ServiceEntry] = {},
        _sorted_prefixes: list[tuple[str, str]] = [];

    def register(service_entry: ServiceEntry) -> None;
    def deregister(name: str) -> bool;
    def match_route(path: str) -> ServiceEntry | None;
    def health_summary -> dict[str, dict];
    def _rebuild_prefix_index -> None;
}
