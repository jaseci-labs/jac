"""Service lifecycle management abstraction.

Implementations own service start / stop / restart / scale / status / logs
for a deployment target. Local subprocess mode is the primary implementer;
K8s mode delegates lifecycle to the K8s controller and implements only
RuntimeServiceResolver, not this interface.

Concrete subclasses declare their own `has registry` field (a
ServiceRegistry from jac_scale.microservices.service_registry); this ABC
stays interface-only to avoid the abstractions -> microservices layering
inversion.
"""


"""Manages the lifecycle of registered microservices. Interface-only;
concrete subclasses own the ServiceRegistry they mutate."""
class ServiceLifecycleManager {
    """Deploy a single service. Returns True on success."""
    def deploy_service(self: ServiceLifecycleManager, name: str) -> bool;

    """Stop a running service. Returns True on success."""
    def stop_service(self: ServiceLifecycleManager, name: str) -> bool;

    """Restart a service (stop + deploy). Returns True on success."""
    def restart_service(self: ServiceLifecycleManager, name: str) -> bool;

    """Scale a service to N replicas. Local mode always 1; K8s overrides."""
    def scale_service(
        self: ServiceLifecycleManager, name: str, replicas: int
    ) -> bool;

    """Get status of all services."""
    def status(self: ServiceLifecycleManager) -> dict[str, dict];

    """Get the last N lines of logs for a service."""
    def get_logs(self: ServiceLifecycleManager, name: str, lines: int = 50) -> str;

    """Stop all services and clean up. Returns True on success."""
    def destroy_all(self: ServiceLifecycleManager) -> bool;

    """Deploy all services registered in the registry. Returns True on success."""
    def deploy_all(self: ServiceLifecycleManager) -> bool;
}
