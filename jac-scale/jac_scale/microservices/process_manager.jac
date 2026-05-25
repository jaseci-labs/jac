"""Manages service subprocess lifecycles in local mode."""

import subprocess;
import logging;
import threading;
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
        # Boot-time per-service /healthz wait. First-pod-boot can cross
        # 30-40s (jac compile + warmpool prefill + byllm import + sqlite
        # create_all + MCP register), so the historical 20s was too tight
        # and falsely flagged slow services as UNHEALTHY for the rest of
        # the pod's lifetime. Override via
        # [plugins.scale.microservices].boot_health_timeout in jac.toml.
        _boot_health_timeout: float = 60.0,
        # Background recovery loop cadence. After the boot wait, a daemon
        # thread re-checks every service this often so a service that
        # missed the boot bar by a few seconds is auto-promoted back to
        # HEALTHY instead of being permanently locked out of the gateway.
        _health_monitor_interval: float = 10.0,
        _health_monitor_thread: (Any | None) = None,
        _health_monitor_stop: (Any | None) = None;

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

    """Start a daemon thread that re-runs check_all_health every
    `interval` seconds, so services that recover after the initial
    boot wait flip back to HEALTHY automatically. Idempotent."""
    def start_health_monitor(interval: float | None = None) -> None;

    """Signal the health-monitor thread to stop and join it. Idempotent."""
    def stop_health_monitor -> None;
}
