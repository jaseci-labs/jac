"""Service deployment interface - abstract base for local and K8s deployers.

Provides a unified API for managing microservice lifecycles that can be
overridden for different deployment targets (local subprocesses, K8s pods, etc.).
"""

import logging;
import from typing { Any }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

glob logger = logging.getLogger(__name__);

"""Abstract deployer interface - override for each deployment target."""
obj ServiceDeployer {
    has registry: ServiceRegistry,
        target: str = "local";

    """Construct the base URL at which this service is reachable.

    The single source of truth for service URLs across the microservice
    stack: the orchestrator, process manager, gateway resolver and
    peer-URL env-var injection all consult this method. Subclasses own
    the transport-specific URL shape:

      LocalDeployer       -> http://127.0.0.1:{service_entry.port}
      KubernetesDeployer  -> http://{svc}.{ns}.svc.cluster.local:{port}

    Keeping URL construction here is what lets us promise 'implement
    the deployer interface, everything else is unchanged' when K8s
    support lands.
    """
    def url_for(service_entry: ServiceEntry) -> str;

    """Deploy a single service. Returns True on success."""
    def deploy_service(name: str) -> bool;

    """Stop a running service. Returns True on success."""
    def stop_service(name: str) -> bool;

    """Restart a service (stop + deploy). Returns True on success."""
    def restart_service(name: str) -> bool;

    """Scale a service to N replicas (K8s only, local always 1)."""
    def scale_service(name: str, replicas: int) -> bool;

    """Get status of all services."""
    def status -> dict[str, dict];

    """Get logs for a service."""
    def get_logs(name: str, lines: int = 50) -> str;

    """Stop all services and clean up."""
    def destroy_all -> bool;

    """Deploy all registered services."""
    def deploy_all -> bool;
}
