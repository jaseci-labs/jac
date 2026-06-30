class ServiceDeployer {
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
