import subprocess;
import logging;
import from pathlib { Path }
import from jaclang.scale.deploy.target.service_deployer { ServiceDeployer }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.orchestrator.process_manager { ServiceProcessManager }

glob logger = logging.getLogger(__name__);

obj LocalDeployer(ServiceDeployer) {
    has registry: ServiceRegistry,
        target: str = "local",
        process_manager: ServiceProcessManager | None = None;

    def _ensure_pm -> ServiceProcessManager;
    def url_for(service_entry: ServiceEntry) -> str;
    def deploy_service(name: str) -> bool;
    def stop_service(name: str) -> bool;
    def restart_service(name: str) -> bool;
    def scale_service(name: str, replicas: int) -> bool;
    def status -> dict[str, dict];
    def get_logs(name: str, lines: int = 50) -> str;
    def destroy_all -> bool;
    def deploy_all -> bool;
}
