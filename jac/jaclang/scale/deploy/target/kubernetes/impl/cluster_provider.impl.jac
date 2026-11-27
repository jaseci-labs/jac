impl AWSProvider.service_url(
    lb_endpoint: (str | None), ingress_node_port: int
) -> (str | None) {
    if lb_endpoint {
        return f"http://{lb_endpoint}";
    }
    return None;
}

impl AWSProvider.needs_nlb_wait -> bool {
    return True;
}

impl LocalProvider.service_url(
    lb_endpoint: (str | None), ingress_node_port: int
) -> (str | None) {
    return f"http://localhost:{ingress_node_port}";
}

impl LocalProvider.needs_nlb_wait -> bool {
    return False;
}
