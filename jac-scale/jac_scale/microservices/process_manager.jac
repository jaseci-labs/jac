"""Manages service subprocess lifecycles in local mode."""

import subprocess;
import logging;
import from typing { Any }
import from urllib.request { urlopen, Request as URLRequest }
import from urllib.error { URLError }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

glob logger = logging.getLogger(__name__);

"""Starts, stops, health-checks, and restarts service subprocesses.

URL construction is delegated to the owning deployer via
`deployer.url_for(entry)`; kept typed as `Any` to avoid a circular
import with `deployer.jac`. LocalDeployer wires itself in through
`_ensure_pm`.
"""
obj ServiceProcessManager {
    has registry: ServiceRegistry,
        deployer: (Any | None) = None,
        processes: dict[str, subprocess.Popen] = {},
        _health_check_timeout: int = 3,
        _max_failures: int = 3,
        _failure_counts: dict[str, int] = {},
        _next_port: int = 8001,
        # Background recovery monitor state. Typed Any to avoid pulling
        # threading.Thread / threading.Event into this declaration file
        # (and to dodge a type-checker warning around Optional[Thread]).
        _health_monitor_thread: (Any | None) = None,
        _health_monitor_stop: (Any | None) = None,
        _health_monitor_interval: float = 5.0,
        _health_lock: (Any | None) = None;

    """Resolve a service's base URL via the owning deployer, with a
    loopback fallback so tests that instantiate ServiceProcessManager
    directly (without a deployer) keep working."""
    def _url_for(service_entry: ServiceEntry) -> str;

    """Assign a port to a service (auto-assign if port=0)."""
    def _assign_port(service_entry: ServiceEntry) -> int;

    """Start a single service subprocess. Returns True on success."""
    def start_service(name: str) -> bool;

    """Start all registered services."""
    def start_all -> None;

    """Stop a single service (graceful SIGTERM, then SIGKILL)."""
    def stop_service(name: str) -> bool;

    """Stop all running services."""
    def stop_all -> None;

    """Restart a service (stop + start)."""
    def restart_service(name: str) -> bool;

    """Check /health on a single service. Returns True if healthy."""
    def check_health(name: str) -> bool;

    """Run health checks on all services. Returns per-service results."""
    def check_all_health -> dict[str, bool];

    """Start the background recovery health monitor.

    Periodically calls check_all_health so a service that crosses the
    startup_timeout bar by a few seconds can be flipped back to HEALTHY.
    Idempotent; safe to call multiple times. Pair with stop_health_monitor
    in shutdown to join the thread cleanly.
    """
    def start_health_monitor(interval: float = 5.0) -> None;

    """Signal the background recovery health monitor to stop and join it."""
    def stop_health_monitor -> None;

    """Internal: the monitor thread body."""
    def _health_monitor_loop -> None;
}
