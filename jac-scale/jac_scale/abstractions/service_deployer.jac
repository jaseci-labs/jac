"""Combined service deployer abstraction.

ServiceDeployer is the union of RuntimeServiceResolver + ServiceLifecycleManager:
implementations that own both URL resolution AND lifecycle management
(today: LocalDeployer; the legacy KubernetesDeployer also extends this
even though its lifecycle methods are no-op stubs).

New microservice implementations should prefer depending on the smaller
RuntimeServiceResolver or ServiceLifecycleManager interfaces directly.
ServiceDeployer is the back-compatible wrapper kept during the M-track
refactor.

Interface-only ABC. Concrete subclasses declare their own `has registry`
field (a ServiceRegistry from jac_scale.microservices.service_registry);
this keeps abstractions/ free of microservices imports.
"""


"""Combined deployer interface: per-service URL resolution + lifecycle
operations. Concrete subclasses (LocalDeployer, KubernetesDeployer)
override the subset of methods relevant to their deployment target."""
class ServiceDeployer {
    """Construct the base URL at which this service is reachable.

    Single source of truth for service URLs across the microservice
    stack: the orchestrator, process manager, gateway resolver, and
    peer-URL env-var injection all consult this method. Subclasses own
    the transport-specific URL shape:

      LocalDeployer       -> http://127.0.0.1:{service_entry.port}
      KubernetesDeployer  -> http://{svc}.{ns}.svc.cluster.local:{port}

    `service_entry` is typed `any` here so abstractions/ doesn't import
    from microservices/; concrete subclasses accept a real ServiceEntry.
    """
    def url_for(self: ServiceDeployer, service_entry: any) -> str;

    """Deploy a single service. Returns True on success."""
    def deploy_service(self: ServiceDeployer, name: str) -> bool;

    """Stop a running service. Returns True on success."""
    def stop_service(self: ServiceDeployer, name: str) -> bool;

    """Restart a service (stop + deploy). Returns True on success."""
    def restart_service(self: ServiceDeployer, name: str) -> bool;

    """Scale a service to N replicas (K8s only; local always 1)."""
    def scale_service(self: ServiceDeployer, name: str, replicas: int) -> bool;

    """Get status of all services."""
    def status(self: ServiceDeployer) -> dict[str, dict];

    """Get the last N lines of logs for a service."""
    def get_logs(self: ServiceDeployer, name: str, lines: int = 50) -> str;

    """Stop all services and clean up. Returns True on success."""
    def destroy_all(self: ServiceDeployer) -> bool;

    """Deploy all registered services. Returns True on success."""
    def deploy_all(self: ServiceDeployer) -> bool;
}
