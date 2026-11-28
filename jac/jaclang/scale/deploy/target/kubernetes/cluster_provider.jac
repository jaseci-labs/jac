obj ClusterProvider {
    def service_url(
        lb_endpoint: (str | None), ingress_node_port: int
    ) -> (str | None) abst;

    def needs_nlb_wait -> bool abst;
}

obj AWSProvider(ClusterProvider) {
    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None);
    def needs_nlb_wait -> bool;
}

obj LocalProvider(ClusterProvider) {
    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None);
    def needs_nlb_wait -> bool;
}
