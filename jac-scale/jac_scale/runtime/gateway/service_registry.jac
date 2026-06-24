"""Service registry — tracks declared microservices and their runtime state."""

import from datetime { datetime }

enum ServiceStatus {
    REGISTERED = "registered",
    STARTING = "starting",
    HEALTHY = "healthy",
    UNHEALTHY = "unhealthy",
    STOPPED = "stopped"
}

"""Represents a single declared microservice."""
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

"""Registry that maps service prefixes to entries with longest-prefix matching."""
obj ServiceRegistry {
    has entries: dict[str, ServiceEntry] = {},
        _sorted_prefixes: list[tuple[str, str]] = [];

    """Register a service entry. Rebuilds prefix index."""
    def register(service_entry: ServiceEntry) -> None;

    """Remove a service by name. Returns True if found."""
    def deregister(name: str) -> bool;

    """Find the service matching a request path (longest-prefix match)."""
    def match_route(path: str) -> ServiceEntry | None;

    """Get all entries as a health summary dict."""
    def health_summary -> dict[str, dict];

    """Rebuild the sorted prefix list after register/deregister."""
    def _rebuild_prefix_index -> None;
}
