impl AWSProvider.service_type -> str {
    return 'LoadBalancer';
}

impl AWSProvider.validate_ports(node_port: int, current_namespace: str) {}

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

impl LocalProvider.service_type -> str {
    return 'NodePort';
}

impl LocalProvider.validate_ports(node_port: int, current_namespace: str) {
    v1 = client.CoreV1Api();
    all_services = v1.list_service_for_all_namespaces();
    used_ports: dict[int, str] = {};

    svc_items: list[any] = all_services.items or [];
    for svc in svc_items {
        if svc.metadata.namespace == current_namespace {
            continue;
        }
        svc_id = f"{svc.metadata.namespace}/{svc.metadata.name}";
        svc_ports: list[any] = svc.spec.ports or [];
        for port_obj in svc_ports {
            if port_obj.node_port is not None {
                used_ports[port_obj.node_port] = svc_id;
            }
        }
    }
    if node_port in used_ports {
        raise ValueError(
            f"NodePort conflict detected on local cluster.\n"
            f"  ingress_node_port={node_port} is already in use by '{used_ports[
                node_port
            ]}'\n"
            f"Please choose a different ingress_node_port value in your KubernetesConfig and try again."
        );
    }
}

impl LocalProvider.service_url(
    lb_endpoint: (str | None), ingress_node_port: int
) -> (str | None) {
    return f"http://localhost:{ingress_node_port}";
}

impl LocalProvider.needs_nlb_wait -> bool {
    return False;
}
