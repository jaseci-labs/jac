"""Service lifecycle management: implementations own deploy / stop /
restart / scale / status / logs / destroy for registered microservices.
Local subprocess mode is the primary implementer; K8s mode delegates
lifecycle to the K8s controller and implements only RuntimeServiceResolver."""


class ServiceLifecycleManager {
    def deploy_service(self: ServiceLifecycleManager, name: str) -> bool;
    def stop_service(self: ServiceLifecycleManager, name: str) -> bool;
    def restart_service(self: ServiceLifecycleManager, name: str) -> bool;
    def scale_service(
        self: ServiceLifecycleManager, name: str, replicas: int
    ) -> bool;
    def status(self: ServiceLifecycleManager) -> dict[str, dict];
    def get_logs(self: ServiceLifecycleManager, name: str, lines: int = 50) -> str;
    def destroy_all(self: ServiceLifecycleManager) -> bool;
    def deploy_all(self: ServiceLifecycleManager) -> bool;
}
