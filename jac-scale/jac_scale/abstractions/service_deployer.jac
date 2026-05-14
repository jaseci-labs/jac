"""ServiceDeployer ABC. Concrete subclasses (LocalDeployer,
K8sRuntimeServiceResolver) declare their own `has registry: ServiceRegistry`
field; this ABC stays interface-only to avoid abstractions -> microservices
layering inversion."""

class ServiceDeployer {
    """Single source of truth for service URLs.
      LocalDeployer       -> http://127.0.0.1:{service_entry.port}
      KubernetesDeployer  -> http://{svc}.{ns}.svc.cluster.local:{port}
    `service_entry: any` keeps this ABC free of microservices imports."""
    def url_for(self: ServiceDeployer, service_entry: any) -> str;

    def deploy_service(self: ServiceDeployer, name: str) -> bool;
    def stop_service(self: ServiceDeployer, name: str) -> bool;
    def restart_service(self: ServiceDeployer, name: str) -> bool;
    def scale_service(self: ServiceDeployer, name: str, replicas: int) -> bool;
    def status(self: ServiceDeployer) -> dict[str, dict];
    def get_logs(self: ServiceDeployer, name: str, lines: int = 50) -> str;
    def destroy_all(self: ServiceDeployer) -> bool;
    def deploy_all(self: ServiceDeployer) -> bool;
}
