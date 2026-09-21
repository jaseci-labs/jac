class ServiceDeployer {
    def url_for(self: ServiceDeployer, service_entry: any) -> str abst;
    def deploy_service(self: ServiceDeployer, name: str) -> bool abst;
    def stop_service(self: ServiceDeployer, name: str) -> bool abst;
    def restart_service(self: ServiceDeployer, name: str) -> bool abst;
    def scale_service(self: ServiceDeployer, name: str, replicas: int) -> bool abst;
    def status(self: ServiceDeployer) -> dict[str, dict[str, any]] abst;
    def get_logs(self: ServiceDeployer, name: str, lines: int = 50) -> str abst;
    def destroy_all(self: ServiceDeployer) -> bool abst;
    def deploy_all(self: ServiceDeployer) -> bool abst;
}
