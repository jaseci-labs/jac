obj ClusterProvider {
    def service_type -> str abst;
    def validate_ports(node_port: int, current_namespace: str) -> None abst;
    def service_url(
        lb_endpoint: (str | None), ingress_node_port: int
    ) -> (str | None) abst;

    def prometheus_scrape_port(container_port: int) -> int abst;
    def ingress_controller_service(
        service_name: str, namespace: str, controller_name: str, ingress_node_port: int
    ) -> dict[str, any] abst;

    def log_ingress_deployed(
        logger: (Logger | None), app_name: str, ingress_node_port: int
    ) -> None abst;

    def needs_nlb_wait -> bool abst;
}

obj AWSProvider(ClusterProvider) {
    def service_type -> str;
    def validate_ports(node_port: int, current_namespace: str);
    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None);
    def prometheus_scrape_port(container_port: int) -> int;
    def ingress_controller_service(
        service_name: str, namespace: str, controller_name: str, ingress_node_port: int
    ) -> dict[str, any];

    def log_ingress_deployed(
        logger: (Logger | None), app_name: str, ingress_node_port: int
    );

    def needs_nlb_wait -> bool;
}

obj LocalProvider(ClusterProvider) {
    def service_type -> str;
    def validate_ports(node_port: int, current_namespace: str);
    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None);
    def prometheus_scrape_port(container_port: int) -> int;
    def ingress_controller_service(
        service_name: str, namespace: str, controller_name: str, ingress_node_port: int
    ) -> dict[str, any];

    def log_ingress_deployed(
        logger: (Logger | None), app_name: str, ingress_node_port: int
    );

    def needs_nlb_wait -> bool;
}
