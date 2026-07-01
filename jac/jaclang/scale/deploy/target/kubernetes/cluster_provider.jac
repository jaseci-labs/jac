import from jaclang.scale._optdeps.kubernetes { client }
import from jaclang.scale.observability.logger { Logger }

obj ClusterProvider {
    def service_type -> str;
    def validate_ports(node_port: int, current_namespace: str) -> None;
    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None);
    def prometheus_scrape_port(container_port: int) -> int;
    def ingress_controller_service(
        service_name: str, namespace: str, controller_name: str, ingress_node_port: int
    ) -> dict;

    def log_ingress_deployed(
        logger: (Logger | None), app_name: str, ingress_node_port: int
    ) -> None;

    def needs_nlb_wait -> bool;
}

obj AWSProvider(ClusterProvider) {
    def service_type -> str {
        return 'LoadBalancer';
    }

    def validate_ports(node_port: int, current_namespace: str) { }
    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None) {
        if lb_endpoint {
            return f"http://{lb_endpoint}";
        }
        return None;
    }

    def prometheus_scrape_port(container_port: int) -> int {
        return container_port;
    }

    def ingress_controller_service(
        service_name: str, namespace: str, controller_name: str, ingress_node_port: int
    ) -> dict {
        return {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': service_name,
                'namespace': namespace,
                'labels': {'app': controller_name, 'managed': 'jac-scale'},
                'annotations': {
                    'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb',
                    'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing'
                }
            },
            'spec': {
                'type': 'LoadBalancer',
                'selector': {'app': controller_name},
                'ports': [
                    {'name': 'http', 'protocol': 'TCP', 'port': 80, 'targetPort': 80},
                    {'name': 'https', 'protocol': 'TCP', 'port': 443, 'targetPort': 443}
                ]
            }
        };
    }

    def log_ingress_deployed(
        logger: (Logger | None), app_name: str, ingress_node_port: int
    ) {
        if logger {
            logger.info(
                f"NGINX ingress controller deployed for '{app_name}' (AWS NLB)"
            );
        }
    }

    def needs_nlb_wait -> bool {
        return True;
    }
}

obj LocalProvider(ClusterProvider) {
    def service_type -> str {
        return 'NodePort';
    }

    def validate_ports(node_port: int, current_namespace: str) {
        v1 = client.CoreV1Api();
        all_services = v1.list_service_for_all_namespaces();
        used_ports: dict[int, str] = {};
        for svc in all_services.items {
            if svc.metadata.namespace == current_namespace {
                continue;
            }
            svc_id = f"{svc.metadata.namespace}/{svc.metadata.name}";
            for port_obj in (svc.spec.ports or []) {
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

    def service_url(lb_endpoint: (str | None), ingress_node_port: int) -> (str | None) {
        return f"http://localhost:{ingress_node_port}";
    }

    def prometheus_scrape_port(container_port: int) -> int {
        return container_port;
    }

    def ingress_controller_service(
        service_name: str, namespace: str, controller_name: str, ingress_node_port: int
    ) -> dict {
        return {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': service_name,
                'namespace': namespace,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'NodePort',
                'selector': {'app': controller_name},
                'ports': [
                    {
                        'name': 'http',
                        'protocol': 'TCP',
                        'port': 80,
                        'targetPort': 80,
                        'nodePort': ingress_node_port
                    },
                    {'name': 'https', 'protocol': 'TCP', 'port': 443, 'targetPort': 443}
                ]
            }
        };
    }

    def log_ingress_deployed(
        logger: (Logger | None), app_name: str, ingress_node_port: int
    ) {
        if logger {
            logger.info(
                f"NGINX ingress controller deployed for '{app_name}' at localhost:{ingress_node_port}"
            );
        }
    }

    def needs_nlb_wait -> bool {
        return False;
    }
}
