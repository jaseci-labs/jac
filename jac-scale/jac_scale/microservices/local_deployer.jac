"""Local deployer - manages microservices as subprocesses.

Wraps ServiceProcessManager with the ServiceDeployer interface so
the same CLI commands work for both local and K8s targets.
"""

import subprocess;
import logging;
import from typing { Any }
import from pathlib { Path }
import from jac_scale.microservices.deployer { ServiceDeployer }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jac_scale.microservices.process_manager { ServiceProcessManager }

glob logger = logging.getLogger(__name__);

"""Local deployer - runs services as subprocesses on the host."""
obj LocalDeployer(ServiceDeployer) {
    has process_manager: ServiceProcessManager | None = None;

    """Initialize the process manager if needed."""
    def _ensure_pm -> ServiceProcessManager;

    """Loopback URL: `http://127.0.0.1:{entry.port}`.

    Matches the `--port` arg we pass to each spawned subprocess and the
    peer-URL env-var fast-path in core's `sv_client._ensure_available`.
    """
    def url_for(service_entry: ServiceEntry) -> str;

    """Deploy a single service as a subprocess."""
    def deploy_service(name: str) -> bool;

    """Stop a running service subprocess."""
    def stop_service(name: str) -> bool;

    """Restart a service (stop + start)."""
    def restart_service(name: str) -> bool;

    """Scale is not supported locally - always 1 replica."""
    def scale_service(name: str, replicas: int) -> bool;

    """Get status of all services."""
    def status -> dict[str, dict];

    """Get logs for a service (reads from log file if available)."""
    def get_logs(name: str, lines: int = 50) -> str;

    """Stop all services."""
    def destroy_all -> bool;

    """Deploy all registered services."""
    def deploy_all -> bool;
}
