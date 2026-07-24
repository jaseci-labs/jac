import time;
import subprocess;
import from jaclang.scale._optdeps.kubernetes { client, ApiException }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    delete_if_exists
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }

def _htpasswd_line(username: str, password: str) -> str {
    require_optional("bcrypt", "deploy.k8s");
    import bcrypt;

    pw_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode(
        'utf-8'
    ).replace(
        '$2b$', '$2y$'
    );
    return f"{username}:{pw_hash}";
}

obj IngressDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    def _deploy_nginx_controller(
        app_name: str,
        namespace: str,
        provider: ClusterProvider,
        apps_v1: Any,
        core_v1: Any,
        rbac_v1: Any,
        networking_v1: Any
    ) {
        controller_name = f"{app_name}-ingress-nginx";
        cluster_resource_name = f"{namespace}-{app_name}-ingress-nginx";
        configmap_name = f"{app_name}-nginx-configuration";
        ingress_class_name = f"{namespace}-{app_name}-nginx";
        service_name = f"{controller_name}-service";

        sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': controller_name,
                'namespace': namespace,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            }
        };
        try {
            core_v1.read_namespaced_service_account(
                name=controller_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(namespace=namespace, body=sa);
            } else {
                raise;
            }
        }

        cluster_role = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {
                'name': cluster_resource_name,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'rules': [
                {
                    'apiGroups': [''],
                    'resources': [
                        'configmaps',
                        'endpoints',
                        'nodes',
                        'pods',
                        'secrets',
                        'namespaces'
                    ],
                    'verbs': ['get', 'list', 'watch']
                },
                {
                    'apiGroups': [''],
                    'resources': ['configmaps'],
                    'verbs': ['create', 'update']
                },
                {
                    'apiGroups': [''],
                    'resources': ['services'],
                    'verbs': ['get', 'list', 'watch']
                },
                {
                    'apiGroups': [''],
                    'resources': ['events'],
                    'verbs': ['create', 'patch']
                },
                {
                    'apiGroups': ['coordination.k8s.io'],
                    'resources': ['leases'],
                    'verbs': ['get', 'list', 'watch', 'create', 'update']
                },
                {
                    'apiGroups': ['networking.k8s.io'],
                    'resources': ['ingresses'],
                    'verbs': ['get', 'list', 'watch']
                },
                {
                    'apiGroups': ['networking.k8s.io'],
                    'resources': ['ingresses/status'],
                    'verbs': ['update']
                },
                {
                    'apiGroups': ['networking.k8s.io'],
                    'resources': ['ingressclasses'],
                    'verbs': ['get', 'list', 'watch']
                },
                {
                    'apiGroups': ['discovery.k8s.io'],
                    'resources': ['endpointslices'],
                    'verbs': ['get', 'list', 'watch']
                }
            ]
        };
        try {
            rbac_v1.read_cluster_role(name=cluster_resource_name);
            rbac_v1.replace_cluster_role(name=cluster_resource_name, body=cluster_role);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role(body=cluster_role);
            } else {
                raise;
            }
        }

        crb = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRoleBinding',
            'metadata': {
                'name': cluster_resource_name,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'roleRef': {
                'apiGroup': 'rbac.authorization.k8s.io',
                'kind': 'ClusterRole',
                'name': cluster_resource_name
            },
            'subjects': [
                {
                    'kind': 'ServiceAccount',
                    'name': controller_name,
                    'namespace': namespace
                }
            ]
        };
        try {
            rbac_v1.read_cluster_role_binding(name=cluster_resource_name);
            rbac_v1.replace_cluster_role_binding(name=cluster_resource_name, body=crb);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role_binding(body=crb);
            } else {
                raise;
            }
        }

        cm = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': configmap_name,
                'namespace': namespace,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'data': {
                'allow-snippet-annotations': 'true',
                'annotations-risk-level': 'Critical',
                'use-gzip': 'true',
                'gzip-types': 'application/javascript text/css application/json image/svg+xml'
            }
        };
        try {
            core_v1.patch_namespaced_config_map(
                name=configmap_name, namespace=namespace, body=cm
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(namespace=namespace, body=cm);
            } else {
                raise;
            }
        }

        ingress_class = {
            'apiVersion': 'networking.k8s.io/v1',
            'kind': 'IngressClass',
            'metadata': {
                'name': ingress_class_name,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'spec': {'controller': 'k8s.io/ingress-nginx'}
        };
        try {
            networking_v1.read_ingress_class(name=ingress_class_name);
        } except ApiException as e {
            if e.status == 404 {
                networking_v1.create_ingress_class(body=ingress_class);
            } else {
                raise;
            }
        }

        controller_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': controller_name,
                'namespace': namespace,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': controller_name}},
                'template': {
                    'metadata': {'labels': {'app': controller_name}},
                    'spec': {
                        'serviceAccountName': controller_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'controller',
                                'image': 'registry.k8s.io/ingress-nginx/controller:v1.12.0',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 101,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {
                                        'drop': ['ALL'],
                                        'add': ['NET_BIND_SERVICE']
                                    },
                                    'seccompProfile': {'type': 'RuntimeDefault'}
                                },
                                'args': [
                                    '/nginx-ingress-controller',
                                    f"--ingress-class={ingress_class_name}",
                                    '--controller-class=k8s.io/ingress-nginx',
                                    f"--watch-namespace={namespace}",
                                    f"--configmap={namespace}/{configmap_name}",
                                    '--election-id=ingress-controller-leader',
                                    '--validating-webhook=',
                                    '--sync-period=5s'
                                ],
                                'env': [
                                    {
                                        'name': 'POD_NAME',
                                        'valueFrom': {
                                            'fieldRef': {'fieldPath': 'metadata.name'}
                                        }
                                    },
                                    {
                                        'name': 'POD_NAMESPACE',
                                        'valueFrom': {
                                            'fieldRef': {
                                                'fieldPath': 'metadata.namespace'
                                            }
                                        }
                                    }
                                ],
                                'ports': [
                                    {'name': 'http', 'containerPort': 80},
                                    {'name': 'https', 'containerPort': 443},
                                    {'name': 'webhook', 'containerPort': 8443}
                                ],
                                'readinessProbe': {
                                    'httpGet': {
                                        'path': '/healthz',
                                        'port': 10254,
                                        'scheme': 'HTTP'
                                    },
                                    'initialDelaySeconds': 10,
                                    'periodSeconds': 10,
                                    'timeoutSeconds': 5,
                                    'failureThreshold': 5
                                },
                                'livenessProbe': {
                                    'httpGet': {
                                        'path': '/healthz',
                                        'port': 10254,
                                        'scheme': 'HTTP'
                                    },
                                    'initialDelaySeconds': 10,
                                    'periodSeconds': 10,
                                    'timeoutSeconds': 5,
                                    'failureThreshold': 5
                                },
                                'resources': {
                                    'requests': {'cpu': '100m', 'memory': '90Mi'},
                                    'limits': {'cpu': '500m', 'memory': '256Mi'}
                                }
                            }
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.patch_namespaced_deployment(
                name=controller_name, namespace=namespace, body=controller_deployment
            );
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=controller_deployment
                );
            } else {
                raise;
            }
        }

        controller_service = provider.ingress_controller_service(
            service_name, namespace, controller_name, self.k8s_config.ingress_node_port
        );
        try {
            core_v1.patch_namespaced_service(
                name=service_name, namespace=namespace, body=controller_service
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=controller_service
                );
            } else {
                raise;
            }
        }

        provider.log_ingress_deployed(
            self.logger, app_name, self.k8s_config.ingress_node_port
        );
    }

    def _resolve_ingress_class(app_name: str, namespace: str) -> str {
        if self.k8s_config.shared_ingress {
            return self.k8s_config.shared_ingress_class;
        }
        return f"{namespace}-{app_name}-nginx";
    }

    def _ingress_path(
        path: str, svc: str, port: int, path_type: str = 'Prefix'
    ) -> dict[str, any] {
        return {
            'path': path,
            'pathType': path_type,
            'backend': {'service': {'name': svc, 'port': {'number': port}}}
        };
    }

    def _domain_rules(http_block: dict, domain: str) -> list {
        return [{'host': domain, 'http': http_block}, {'http': http_block}];
    }

    def _wait_for_nginx_ready(
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

    def _deploy_ingress_resource(
        app_name: str,
        namespace: str,
        ingress_class: str,
        service_port: int,
        grafana_enabled: bool,
        redis_dashboard: bool,
        mongo_dashboard: bool,
        networking_v1: any,
        core_v1: any
    ) {
        ingress_name = f"{app_name}-ingress";
        redis_ingress_name = f"{app_name}-redis-insight-ingress";

        paths = [self._ingress_path('/', f"{app_name}-service", service_port)];

        if grafana_enabled {
            paths.append(
                self._ingress_path('/grafana', f"{app_name}-grafana-service", 3000)
            );
        }

        if mongo_dashboard {
            paths.append(
                self._ingress_path(
                    '/db-dashboard', f"{app_name}-mongo-express-service", 8081
                )
            );
        }

        if self.k8s_config.shared_ingress {
            main_rules: list = [
                {'host': self.k8s_config.domain, 'http': {'paths': paths}}
            ];
        } elif self.k8s_config.domain {
            main_rules: list = self._domain_rules(
                {'paths': paths}, self.k8s_config.domain
            );
        } else {
            main_rules: list = [{'http': {'paths': paths}}];
        }

        uses_nginx: bool = (not self.k8s_config.shared_ingress)
        or (self.k8s_config.shared_ingress_class == 'nginx');
        ingress_annotations: dict = {};
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
                ingress_annotations[
                    'nginx.ingress.kubernetes.io/session-cookie-name'
                ] = 'route';
                ingress_annotations[
                    'nginx.ingress.kubernetes.io/session-cookie-max-age'
                ] = '2147483647';
                ingress_annotations[
                    'nginx.ingress.kubernetes.io/session-cookie-expires'
                ] = '2147483647';
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
        main_spec: dict = {'ingressClassName': ingress_class, 'rules': main_rules};

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
                'labels': {'app': app_name, 'managed': 'jac-scale'},
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

        if redis_dashboard {
            ri_username = self.k8s_config.redis_insight_username;
            ri_password = self.k8s_config.redis_insight_password;
            ri_auth_secret_name = f"{app_name}-redis-insight-auth";

            htpasswd_line = _htpasswd_line(ri_username, ri_password);
            ri_auth_secret = {
                'apiVersion': 'v1',
                'kind': 'Secret',
                'metadata': {
                    'name': ri_auth_secret_name,
                    'namespace': namespace,
                    'labels': {
                        'app': f"{app_name}-redis-insight",
                        'managed': 'jac-scale'
                    }
                },
                'stringData': {'auth': htpasswd_line}
            };
            try {
                core_v1.replace_namespaced_secret(
                    name=ri_auth_secret_name, namespace=namespace, body=ri_auth_secret
                );
            } except ApiException as e {
                if e.status == 404 {
                    core_v1.create_namespaced_secret(
                        namespace=namespace, body=ri_auth_secret
                    );
                } else {
                    raise;
                }
            }

            redis_ingress_annotations: dict = {
                'nginx.ingress.kubernetes.io/proxy-body-size': '0',
                'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600',
                'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600',
                'nginx.ingress.kubernetes.io/proxy-buffering': 'on',
                'nginx.ingress.kubernetes.io/use-regex': 'true',
                'nginx.ingress.kubernetes.io/rewrite-target': '/$2',
                'nginx.ingress.kubernetes.io/configuration-snippet': (
                    'proxy_set_header Accept-Encoding "";\n'
                    'sub_filter_types text/html;\n'
                    'sub_filter \'src="/assets/\' \'src="/cache-dashboard/assets/\';\n'
                    'sub_filter \'href="/assets/\' \'href="/cache-dashboard/assets/\';\n'
                    'sub_filter "var RIPROXYPATH = \'\';" "var RIPROXYPATH = \'/cache-dashboard\';";\n'
                    'sub_filter_once off;'
                )
            };
            redis_ingress_annotations['nginx.ingress.kubernetes.io/auth-type'] = 'basic';
            redis_ingress_annotations['nginx.ingress.kubernetes.io/auth-secret'] = ri_auth_secret_name;
            redis_ingress_annotations['nginx.ingress.kubernetes.io/auth-realm'] = 'RedisInsight';

            redis_paths = [
                self._ingress_path(
                    '/cache-dashboard(/|$)(.*)',
                    f"{app_name}-redis-insight-service",
                    5540,
                    path_type='ImplementationSpecific'
                )
            ];

            if self.k8s_config.shared_ingress {
                redis_rules: list = [
                    {'host': self.k8s_config.domain, 'http': {'paths': redis_paths}}
                ];
            } elif self.k8s_config.domain {
                redis_rules: list = self._domain_rules(
                    {'paths': redis_paths}, self.k8s_config.domain
                );
            } else {
                redis_rules: list = [{'http': {'paths': redis_paths}}];
            }

            redis_ingress = {
                'apiVersion': 'networking.k8s.io/v1',
                'kind': 'Ingress',
                'metadata': {
                    'name': redis_ingress_name,
                    'namespace': namespace,
                    'labels': {'app': app_name, 'managed': 'jac-scale'},
                    'annotations': redis_ingress_annotations
                },
                'spec': {'ingressClassName': ingress_class, 'rules': redis_rules}
            };
            try {
                networking_v1.patch_namespaced_ingress(
                    name=redis_ingress_name, namespace=namespace, body=redis_ingress
                );
            } except ApiException as e {
                if e.status == 404 {
                    networking_v1.create_namespaced_ingress(
                        namespace=namespace, body=redis_ingress
                    );
                } else {
                    raise;
                }
            }
        } else {
            delete_if_exists(
                networking_v1.delete_namespaced_ingress,
                redis_ingress_name,
                namespace,
                'Ingress'
            );
            delete_if_exists(
                core_v1.delete_namespaced_secret,
                f"{app_name}-redis-insight-auth",
                namespace,
                'Secret'
            );
        }

        if self.logger {
            self.logger.info(f"Ingress routing rules deployed for '{app_name}'");
        }
    }

    def start_controller(
        app_name: str,
        namespace: str,
        provider: ClusterProvider,
        apps_v1: Any,
        core_v1: Any,
        rbac_v1: Any,
        networking_v1: Any
    ) {
        if not self.k8s_config.shared_ingress {
            self._deploy_nginx_controller(
                app_name, namespace, provider, apps_v1, core_v1, rbac_v1, networking_v1
            );
        } else {
            cls = self.k8s_config.shared_ingress_class;
            try {
                networking_v1.read_ingress_class(name=cls);
            } except ApiException as e {
                if e.status == 404 {
                    raise ValueError(
                        f"shared_ingress_class '{cls}' has no matching IngressClass "
                        "in the cluster. Install that ingress controller, or set "
                        "shared_ingress_class to one that exists (e.g. 'alb' on AWS "
                        "EKS, or 'nginx' where ingress-nginx is installed)."
                    );
                } else {
                    raise;
                }
            }
            if self.logger {
                self.logger.info(
                    f"shared_ingress=True: skipping dedicated controller for "
                    f"'{app_name}', using ingress class '{cls}'"
                );
            }
        }
    }

    def finish_ingress(
        app_name: str,
        namespace: str,
        service_port: int,
        grafana_enabled: bool,
        redis_dashboard: bool,
        mongo_dashboard: bool,
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
            redis_dashboard,
            mongo_dashboard,
            networking_v1,
            core_v1
        );
    }

    def _install_cert_manager(
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
                    [
                        'kubectl',
                        'apply',
                        '-f',
                        'https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml'
                    ],
                    capture_output=True,
                    text=True,
                    timeout=120
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
                        {
                            'http01': {
                                'ingress': {'ingressClassName': ingress_class_name}
                            }
                        }
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

    def enable_tls(
        app_name: str,
        namespace: str,
        networking_v1: any,
        custom_api: any,
        core_v1: any,
        apps_v1: any
    ) -> None {
        ingress_name = f"{app_name}-ingress";
        redis_ingress_name = f"{app_name}-redis-insight-ingress";
        tls_secret_name = f"{app_name}-tls";

        ingress = networking_v1.read_namespaced_ingress(
            name=ingress_name, namespace=namespace
        );
        ann = ingress.metadata.annotations or {};
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
        tls_spec = {'tls': [{'hosts': [domain], 'secretName': tls_secret_name}]};

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

        try {
            current_redis_ingress = networking_v1.read_namespaced_ingress(
                name=redis_ingress_name, namespace=namespace
            );
            redis_ingress_dict = api_client.sanitize_for_serialization(
                current_redis_ingress
            );
            existing_redis_rules = redis_ingress_dict.get('spec', {}).get('rules', []);
            redis_base_http = existing_redis_rules[0].get('http', {'paths': []})
                if existing_redis_rules
                else {'paths': []};
            if self.k8s_config.shared_ingress {
                redis_rules_patched = [{'host': domain, 'http': redis_base_http}];
            } else {
                redis_rules_patched = self._domain_rules(redis_base_http, domain);
            }
            redis_tls_spec = {
                'tls': [{'hosts': [domain], 'secretName': tls_secret_name}],
                'rules': redis_rules_patched
            };
            networking_v1.patch_namespaced_ingress(
                name=redis_ingress_name,
                namespace=namespace,
                body={
                    'metadata': {'annotations': tls_annotations},
                    'spec': redis_tls_spec
                }
            );
            if self.logger {
                self.logger.info(
                    f"Patched '{redis_ingress_name}' with TLS configuration"
                );
            }
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
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
            self.logger.warning(
                f"Timeout: certificate '{tls_secret_name}' not Ready after 300s. "
                "Check: kubectl describe certificate "
                f"{tls_secret_name} -n {namespace}"
            );
        }
    }

    def destroy(
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
        redis_ingress_name = f"{app_name}-redis-insight-ingress";
        service_name = f"{controller_name}-service";
        configmap_name = f"{app_name}-nginx-configuration";

        delete_if_exists(
            networking_v1.delete_namespaced_ingress, ingress_name, namespace, 'Ingress'
        );
        delete_if_exists(
            networking_v1.delete_namespaced_ingress,
            redis_ingress_name,
            namespace,
            'Ingress'
        );
        delete_if_exists(
            core_v1.delete_namespaced_secret,
            f"{app_name}-redis-insight-auth",
            namespace,
            'Secret'
        );

        delete_if_exists(
            core_v1.delete_namespaced_secret, f"{app_name}-tls", namespace, 'Secret'
        );
        delete_if_exists(
            core_v1.delete_namespaced_secret,
            'letsencrypt-prod-key',
            namespace,
            'Secret'
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
                core_v1.delete_namespaced_config_map,
                configmap_name,
                namespace,
                'ConfigMap'
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
}
