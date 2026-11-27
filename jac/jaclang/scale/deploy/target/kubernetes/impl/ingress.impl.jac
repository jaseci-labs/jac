impl IngressDeployer._resolve_ingress_class(app_name: str, namespace: str) -> str {
    if self.k8s_config.shared_ingress {
        return self.k8s_config.shared_ingress_class;
    }
    return f"{namespace}-{app_name}-nginx";
}

impl IngressDeployer._ingress_path(
    path: str, svc: str, port: int, path_type: str = 'Prefix'
) -> dict[str, any] {
    return {
        'path': path,
        'pathType': path_type,
        'backend': {'service': {'name': svc, 'port': {'number': port}}}
    };
}

impl IngressDeployer._domain_rules(
    http_block: dict[str, any], domain: str
) -> list[dict[str, any]] {
    return [{'host': domain, 'http': http_block}, {'http': http_block}];
}

impl IngressDeployer._wait_for_nginx_ready(
    app_name: str, namespace: str, apps_v1: any, max_wait: int = 180
) -> None {
    if self.k8s_config.shared_ingress {
        return;
    }
    controller_name = f"{app_name}-ingress-nginx";
    elapsed = 0;
    poll = 5;
    while elapsed < max_wait {
        try {
            deploy = apps_v1.read_namespaced_deployment(
                name=controller_name, namespace=namespace
            );
            ready = deploy.status.ready_replicas or 0;
            if ready >= 1 {
                if self.logger {
                    self.logger.info(
                        f"NGINX controller '{controller_name}' is ready ({elapsed}s)"
                    );
                }
                return;
            }
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        time.sleep(poll);
        elapsed = elapsed + poll;
    }
    if self.logger {
        self.logger.warn(
            f"NGINX controller '{controller_name}' not ready after {max_wait}s, proceeding anyway"
        );
    }
}

impl IngressDeployer._deploy_ingress_resource(
    app_name: str,
    namespace: str,
    ingress_class: str,
    service_port: int,
    grafana_enabled: bool,
    networking_v1: any,
    core_v1: any
) {
    ingress_name = f"{app_name}-ingress";

    paths = [self._ingress_path('/', f"{app_name}-service", service_port)];

    if grafana_enabled {
        paths.append(
            self._ingress_path('/grafana', f"{app_name}-grafana-service", 3000)
        );
    }

    if self.k8s_config.shared_ingress {
        main_rules: list[dict[str, any]] = [
            {'host': self.k8s_config.domain, 'http': {'paths': paths}}
        ];
    } elif self.k8s_config.domain {
        main_rules: list[dict[str, any]] = self._domain_rules(
            {'paths': paths}, self.k8s_config.domain
        );
    } else {
        main_rules: list[dict[str, any]] = [{'http': {'paths': paths}}];
    }

    uses_nginx: bool = (not self.k8s_config.shared_ingress)
        or (self.k8s_config.shared_ingress_class == 'nginx');
    ingress_annotations: dict[str, any] = {};
    if uses_nginx {
        ingress_annotations = {
            'nginx.ingress.kubernetes.io/proxy-body-size': '0',
            'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600',
            'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600',
            'nginx.ingress.kubernetes.io/limit-rps': str(
                self.k8s_config.ingress_limit_rps
            ),
            'nginx.ingress.kubernetes.io/limit-burst-multiplier': str(
                self.k8s_config.ingress_limit_burst_multiplier
            ),
            'nginx.ingress.kubernetes.io/limit-connections': str(
                self.k8s_config.ingress_limit_connections
            ),
            'nginx.ingress.kubernetes.io/limit-req-status-code': '429'
        };
        if self.k8s_config.ingress_session_affinity {
            ingress_annotations['nginx.ingress.kubernetes.io/affinity'] = 'cookie';
            ingress_annotations['nginx.ingress.kubernetes.io/session-cookie-name'] = 'route';
            ingress_annotations['nginx.ingress.kubernetes.io/session-cookie-max-age'] = '2147483647';
            ingress_annotations['nginx.ingress.kubernetes.io/session-cookie-expires'] = '2147483647';
            ingress_annotations[
                'nginx.ingress.kubernetes.io/session-cookie-change-on-failure'
            ] = 'true';
        }
    }
    if self.k8s_config.domain {
        ingress_annotations['jac-scale/domain'] = self.k8s_config.domain;
    }
    if self.k8s_config.cert_manager_email {
        ingress_annotations['jac-scale/cert-email'] = self.k8s_config.cert_manager_email;
    }

    for (k, v) in self.k8s_config.shared_ingress_annotations.items() {
        ingress_annotations[str(k)] = str(v);
    }
    main_spec: dict[str, any] = {
        'ingressClassName': ingress_class,
        'rules': main_rules
    };

    cert_manager_managed = (
        'cert-manager.io/cluster-issuer' in self.k8s_config.shared_ingress_annotations
        or 'cert-manager.io/issuer' in self.k8s_config.shared_ingress_annotations
    );

    if self.k8s_config.shared_ingress {
        if (
            self.k8s_config.shared_ingress_tls
            and cert_manager_managed
            and self.k8s_config.domain
        ) {
            main_spec['tls'] = [
                {'hosts': [self.k8s_config.domain], 'secretName': f"{app_name}-tls"}
            ];
        } else {
            main_spec['tls'] = None;
        }
    }
    main_ingress = {
        'apiVersion': 'networking.k8s.io/v1',
        'kind': 'Ingress',
        'metadata': {
            'name': ingress_name,
            'namespace': namespace,
            'labels': {
                'app': app_name,
                'managed': 'jac-scale',
                'jac-scale.role': 'gateway'
            },
            'annotations': ingress_annotations
        },
        'spec': main_spec
    };
    try {
        networking_v1.patch_namespaced_ingress(
            name=ingress_name, namespace=namespace, body=main_ingress
        );
    } except ApiException as e {
        if e.status == 404 {
            networking_v1.create_namespaced_ingress(
                namespace=namespace, body=main_ingress
            );
        } else {
            raise;
        }
    }

    if self.logger {
        self.logger.info(f"Ingress routing rules deployed for '{app_name}'");
    }
}

impl IngressDeployer.finish_ingress(
    app_name: str,
    namespace: str,
    service_port: int,
    grafana_enabled: bool,
    apps_v1: any,
    core_v1: any,
    networking_v1: any
) {
    ingress_class = self._resolve_ingress_class(app_name, namespace);
    self._wait_for_nginx_ready(app_name, namespace, apps_v1);
    self._deploy_ingress_resource(
        app_name,
        namespace,
        ingress_class,
        service_port,
        grafana_enabled,
        networking_v1,
        core_v1
    );
}

impl IngressDeployer._install_cert_manager(
    app_name: str,
    namespace: str,
    cert_manager_email: str,
    core_v1: any,
    apps_v1: any,
    custom_api: any
) -> None {
    try {
        custom_api.get_namespaced_custom_object(
            group='cert-manager.io',
            version='v1',
            namespace=namespace,
            plural='issuers',
            name='letsencrypt-prod'
        );
        if self.logger {
            self.logger.info(
                "cert-manager Issuer 'letsencrypt-prod' already exists, skipping"
            );
        }
        return;
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }

    try {
        core_v1.read_namespace(name='cert-manager');
        if self.logger {
            self.logger.info("cert-manager namespace already exists");
        }
    } except ApiException as e {
        if e.status == 404 {
            if self.logger {
                self.logger.info("Installing cert-manager v1.14.5...");
            }
            result = subprocess.run(
                self.kubectl.command(
                    [
                        'apply',
                        '-f',
                        'https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml'
                    ]
                ),
                capture_output=True,
                text=True,
                timeout=120,
                env=self.kubectl.environ()
            );
            if result.returncode != 0 {
                raise Exception(f"cert-manager install failed: {result.stderr}");
            }
            if self.logger {
                self.logger.info("cert-manager manifests applied");
            }
        } else {
            raise;
        }
    }

    if self.logger {
        self.logger.info(
            "Waiting for cert-manager webhook to be ready (up to 120s)..."
        );
    }
    elapsed = 0;
    while elapsed < 120 {
        try {
            d = apps_v1.read_namespaced_deployment(
                name='cert-manager-webhook', namespace='cert-manager'
            );
            if (d.status.ready_replicas or 0) >= 1 {
                if self.logger {
                    self.logger.info(f"cert-manager webhook ready ({elapsed}s)");
                }
                break;
            }
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        time.sleep(5);
        elapsed = elapsed + 5;
    }

    ingress_class_name = self._resolve_ingress_class(app_name, namespace);
    issuer_body = {
        'apiVersion': 'cert-manager.io/v1',
        'kind': 'Issuer',
        'metadata': {
            'name': 'letsencrypt-prod',
            'namespace': namespace,
            'labels': {'managed': 'jac-scale'}
        },
        'spec': {
            'acme': {
                'server': 'https://acme-v02.api.letsencrypt.org/directory',
                'email': cert_manager_email,
                'privateKeySecretRef': {'name': 'letsencrypt-prod-key'},
                'solvers': [
                    {'http01': {'ingress': {'ingressClassName': ingress_class_name}}}
                ]
            }
        }
    };
    try {
        custom_api.create_namespaced_custom_object(
            group='cert-manager.io',
            version='v1',
            namespace=namespace,
            plural='issuers',
            body=issuer_body
        );
        if self.logger {
            self.logger.info(
                f"Created letsencrypt-prod Issuer for ingress class '{ingress_class_name}'"
            );
        }
    } except ApiException as e {
        if e.status != 409 {
            raise;
        }
    }
}

impl IngressDeployer.enable_tls(
    app_name: str,
    namespace: str,
    networking_v1: any,
    custom_api: any,
    core_v1: any,
    apps_v1: any
) -> None {
    ingress_name = f"{app_name}-ingress";
    tls_secret_name = f"{app_name}-tls";

    ingress = networking_v1.read_namespaced_ingress(
        name=ingress_name, namespace=namespace
    );
    ann: dict[str, str] = ingress.metadata.annotations or {};
    domain = ann.get('jac-scale/domain', '') or self.k8s_config.domain;
    cert_email = ann.get('jac-scale/cert-email', '')
        or self.k8s_config.cert_manager_email;

    if not domain {
        raise Exception(
            "No domain found. Re-deploy with 'domain' set in KubernetesConfig."
        );
    }
    if not cert_email {
        raise Exception(
            "No cert_manager_email found. Re-deploy with 'cert_manager_email' set in KubernetesConfig."
        );
    }

    self._install_cert_manager(
        app_name, namespace, cert_email, core_v1, apps_v1, custom_api
    );

    tls_annotations = {
        'cert-manager.io/issuer': 'letsencrypt-prod',
        'nginx.ingress.kubernetes.io/ssl-redirect': 'true',
        'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
        'jac-scale/domain': domain
    };
    tls_spec: dict[str, list[dict[str, any]]] = {
        'tls': [{'hosts': [domain], 'secretName': tls_secret_name}]
    };

    api_client = client.ApiClient();
    current_ingress = networking_v1.read_namespaced_ingress(
        name=ingress_name, namespace=namespace
    );
    ingress_dict = api_client.sanitize_for_serialization(current_ingress);
    existing_rules = ingress_dict.get('spec', {}).get('rules', []);

    base_http = existing_rules[0].get('http', {'paths': []})
        if existing_rules
        else {'paths': []};

    if self.k8s_config.shared_ingress {
        tls_spec['rules'] = [{'host': domain, 'http': base_http}];
    } else {
        tls_spec['rules'] = self._domain_rules(base_http, domain);
    }
    networking_v1.patch_namespaced_ingress(
        name=ingress_name,
        namespace=namespace,
        body={'metadata': {'annotations': tls_annotations}, 'spec': tls_spec}
    );
    if self.logger {
        self.logger.info(f"Patched '{ingress_name}' with TLS configuration");
    }

    if self.logger {
        self.logger.info(
            f"Waiting for TLS certificate '{tls_secret_name}' to be issued (up to 300s)..."
        );
    }
    elapsed = 0;
    while elapsed < 300 {
        try {
            cert = custom_api.get_namespaced_custom_object(
                group='cert-manager.io',
                version='v1',
                namespace=namespace,
                plural='certificates',
                name=tls_secret_name
            );
            for cond in cert.get('status', {}).get('conditions', []) {
                if cond.get('type') == 'Ready' and cond.get('status') == 'True' {
                    if self.logger {
                        self.logger.info(
                            f"Certificate '{tls_secret_name}' is Ready ({elapsed}s)"
                        );
                    }
                    return;
                }
            }
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        time.sleep(5);
        elapsed = elapsed + 5;
    }
    if self.logger {
        self.logger.warn(
            f"Timeout: certificate '{tls_secret_name}' not Ready after 300s. "
            "Check: kubectl describe certificate "
            f"{tls_secret_name} -n {namespace}"
        );
    }
}

impl IngressDeployer.destroy(
    app_name: str,
    namespace: str,
    apps_v1: any,
    core_v1: any,
    rbac_v1: any,
    networking_v1: any
) {
    controller_name = f"{app_name}-ingress-nginx";
    cluster_resource_name = f"{namespace}-{app_name}-ingress-nginx";
    ingress_class_name = f"{namespace}-{app_name}-nginx";
    ingress_name = f"{app_name}-ingress";
    service_name = f"{controller_name}-service";
    configmap_name = f"{app_name}-nginx-configuration";

    delete_if_exists(
        networking_v1.delete_namespaced_ingress, ingress_name, namespace, 'Ingress'
    );
    delete_if_exists(
        core_v1.delete_namespaced_secret, f"{app_name}-tls", namespace, 'Secret'
    );
    delete_if_exists(
        core_v1.delete_namespaced_secret, 'letsencrypt-prod-key', namespace, 'Secret'
    );
    try {
        custom_api = client.CustomObjectsApi();
        custom_api.delete_namespaced_custom_object(
            group='cert-manager.io',
            version='v1',
            namespace=namespace,
            plural='certificates',
            name=f"{app_name}-tls"
        );
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }
    try {
        custom_api.delete_namespaced_custom_object(
            group='cert-manager.io',
            version='v1',
            namespace=namespace,
            plural='issuers',
            name='letsencrypt-prod'
        );
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }

    if not self.k8s_config.shared_ingress {
        delete_if_exists(
            apps_v1.delete_namespaced_deployment,
            controller_name,
            namespace,
            'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service, service_name, namespace, 'Service'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            controller_name,
            namespace,
            'ServiceAccount'
        );
        delete_if_exists(
            core_v1.delete_namespaced_config_map, configmap_name, namespace, 'ConfigMap'
        );
        try {
            rbac_v1.delete_cluster_role(name=cluster_resource_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            rbac_v1.delete_cluster_role_binding(name=cluster_resource_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            networking_v1.delete_ingress_class(name=ingress_class_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
    }

    if self.logger {
        self.logger.info(f"Ingress resources destroyed for '{app_name}'");
    }
}
