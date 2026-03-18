"""NGINX Ingress controller and Ingress resource deployer."""
import time;
import subprocess;
import bcrypt;
import from typing { Any }
import from kubernetes { client }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils { delete_if_exists }
import from kubernetes.client.exceptions { ApiException }

"""Deploys and manages an app-scoped NGINX Ingress controller plus Ingress routing rules.

One controller per app, identified by ingress class '{app_name}-nginx'.

Routes (local: http://<node-ip>:30080, AWS: NLB port 80):
  /               -> {app_name}-service
  /grafana        -> {app_name}-grafana-service   (Grafana handles subpath via GF_SERVER env)
  /db-dashboard  -> {app_name}-mongo-express-service  (MongoExpress handles subpath via ME_CONFIG_SITE_BASEURL)
  /cache-dashboard  -> {app_name}-redis-insight-service  (separate Ingress with rewrite-target)
"""
obj IngressDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    """Deploy the NGINX Ingress controller: ServiceAccount, ClusterRole, ClusterRoleBinding,
    ConfigMap, IngressClass, Deployment, and Service (NodePort locally / NLB on AWS)."""
    def _deploy_nginx_controller(
        app_name: str,
        namespace: str,
        cluster_env: str,
        apps_v1: Any,
        core_v1: Any,
        rbac_v1: Any,
        networking_v1: Any
    ) -> None {
        controller_name = f"{app_name}-ingress-nginx";
        cluster_resource_name = f"{namespace}-{app_name}-ingress-nginx";
        configmap_name = f"{app_name}-nginx-configuration";
        ingress_class_name = f"{namespace}-{app_name}-nginx";
        service_name = f"{controller_name}-service";

        # --- ServiceAccount ---
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

        # --- ClusterRole ---
        cluster_role = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {
                'name': cluster_resource_name,
                'labels': {'app': controller_name, 'managed': 'jac-scale'}
            },
            'rules': [
                # Core reads (cluster-wide)
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
                # ConfigMap writes (leader-election lock)
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
                # Leader-election leases
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

        # --- ClusterRoleBinding ---
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

        # --- ConfigMap ---
        # allow-snippet-annotations + annotations-risk-level: Critical are required
        # so that configuration-snippet annotations on Ingress resources (e.g.
        # sub_filter for RedisInsight asset path rewriting) are accepted by the
        # controller. Disabled by default in nginx-ingress >= v1.9.0; enabling it
        # allows any principal with Ingress write access in this namespace to inject
        # arbitrary NGINX config snippets. Avoid in multi-tenant clusters where
        # untrusted users can create Ingress resources.
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
                'annotations-risk-level': 'Critical'
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

        # --- IngressClass ---
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

        # --- Controller Deployment ---
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
                                    'failureThreshold': 3
                                },
                                'livenessProbe': {
                                    'httpGet': {
                                        'path': '/healthz',
                                        'port': 10254,
                                        'scheme': 'HTTP'
                                    },
                                    'initialDelaySeconds': 10,
                                    'periodSeconds': 10,
                                    'failureThreshold': 3
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

        # --- Service: NodePort locally, NLB on AWS ---
        if cluster_env == 'aws' {
            controller_service = {
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
                        {
                            'name': 'http',
                            'protocol': 'TCP',
                            'port': 80,
                            'targetPort': 80
                        },
                        {
                            'name': 'https',
                            'protocol': 'TCP',
                            'port': 443,
                            'targetPort': 443
                        }
                    ]
                }
            };
        } else {
            controller_service = {
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
                            'nodePort': self.k8s_config.ingress_node_port
                        },
                        {
                            'name': 'https',
                            'protocol': 'TCP',
                            'port': 443,
                            'targetPort': 443
                        }
                    ]
                }
            };
        }
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

        if self.logger {
            if cluster_env == 'aws' {
                self.logger.info(
                    f"NGINX ingress controller deployed for '{app_name}' (AWS NLB)"
                );
            } else {
                self.logger.info(
                    f"NGINX ingress controller deployed for '{app_name}' at localhost:{self.k8s_config.ingress_node_port}"
                );
            }
        }
    }

    """Wait for the NGINX controller Deployment to have at least one ready replica.

    Polls every 5 seconds for up to max_wait seconds. This avoids burning the
    longer app health-check intervals (15 s each) while NGINX is still starting.
    """
    def _wait_for_nginx_ready(
        app_name: str, namespace: str, apps_v1: Any, max_wait: int = 180
    ) -> None {
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

    """Deploy Ingress routing rules.

    Main Ingress: routes /, /grafana (if enabled), /db-dashboard (if enabled).
    RedisInsight Ingress (separate): routes /cache-dashboard with rewrite-target so the
    prefix is stripped before hitting the service.
    """
    def _deploy_ingress_resource(
        app_name: str,
        namespace: str,
        ingress_class: str,
        service_port: int,
        grafana_enabled: bool,
        redis_dashboard: bool,
        mongo_dashboard: bool,
        networking_v1: Any,
        core_v1: Any
    ) -> None {
        ingress_name = f"{app_name}-ingress";
        redis_ingress_name = f"{app_name}-redis-insight-ingress";

        # --- Build main ingress paths ---
        paths = [
            {
                'path': '/',
                'pathType': 'Prefix',
                'backend': {
                    'service': {
                        'name': f"{app_name}-service",
                        'port': {'number': service_port}
                    }
                }
            }
        ];

        if grafana_enabled {
            paths.append(
                {
                    'path': '/grafana',
                    'pathType': 'Prefix',
                    'backend': {
                        'service': {
                            'name': f"{app_name}-grafana-service",
                            'port': {'number': 3000}
                        }
                    }
                }
            );
        }

        if mongo_dashboard {
            paths.append(
                {
                    'path': '/db-dashboard',
                    'pathType': 'Prefix',
                    'backend': {
                        'service': {
                            'name': f"{app_name}-mongo-express-service",
                            'port': {'number': 8081}
                        }
                    }
                }
            );
        }

        main_rule: dict;
        if self.k8s_config.domain {
            main_rule = {'host': self.k8s_config.domain, 'http': {'paths': paths}};
        } else {
            main_rule = {'http': {'paths': paths}};
        }

        ingress_annotations: dict = {
            'nginx.ingress.kubernetes.io/proxy-body-size': '0',
            'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600',
            'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600'
        };
        if self.k8s_config.domain {
            ingress_annotations['jac-scale/domain'] = self.k8s_config.domain;
        }
        if self.k8s_config.cert_manager_email {
            ingress_annotations['jac-scale/cert-email'] = self.k8s_config.cert_manager_email;
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
            'spec': {'ingressClassName': ingress_class, 'rules': [main_rule]}
        };
        try {
            networking_v1.replace_namespaced_ingress(
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

        # --- RedisInsight Ingress ---
        # Auth is enforced by NGINX Ingress basic-auth annotations — no sidecar needed.
        # RIPROXYPATH=/cache-dashboard is set on the container so the ingress passes
        # the full /cache-dashboard/... path unchanged (no rewrite-target).
        if redis_dashboard {
            ri_username = self.k8s_config.redis_insight_username;
            ri_password = self.k8s_config.redis_insight_password;
            ri_auth_secret_name = f"{app_name}-redis-insight-auth";

            # Create/update the NGINX Ingress basic-auth secret.
            # The secret must have key 'auth' containing an htpasswd-formatted string.
            # Format: username:<bcrypt-hash>  ($2y$ prefix required by NGINX Ingress)
            pw_hash = bcrypt.hashpw(
                ri_password.encode('utf-8'), bcrypt.gensalt()
            ).decode(
                'utf-8'
            ).replace(
                '$2b$', '$2y$'
            );
            htpasswd_line = f"{ri_username}:{pw_hash}";
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

            # RedisInsight v3 (Vite build) emits root-relative asset URLs (/assets/...)
            # regardless of RIPROXYPATH. The ingress uses rewrite-target=/$2 to strip the
            # /cache-dashboard prefix before forwarding to the backend, so /assets/... is
            # served correctly. sub_filter rewrites asset URLs in the HTML so the browser
            # requests /cache-dashboard/assets/... (which nginx then rewrites back to
            # /assets/... for the backend). RIPROXYPATH is also rewritten so the JS
            # frontend sets window.__RI_PROXY_PATH__ = 'cache-dashboard' and prefixes all
            # API/socket calls with /cache-dashboard (which nginx strips via rewrite-target).
            # Accept-Encoding is cleared so nginx can apply sub_filter to uncompressed HTML.
            redis_ingress_annotations: dict = {
                'nginx.ingress.kubernetes.io/proxy-body-size': '0',
                'nginx.ingress.kubernetes.io/proxy-read-timeout': '3600',
                'nginx.ingress.kubernetes.io/proxy-send-timeout': '3600',
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

            redis_rule: dict;
            redis_paths = [
                {
                    'path': '/cache-dashboard(/|$)(.*)',
                    'pathType': 'ImplementationSpecific',
                    'backend': {
                        'service': {
                            'name': f"{app_name}-redis-insight-service",
                            'port': {'number': 5540}
                        }
                    }
                }
            ];
            if self.k8s_config.domain {
                redis_rule = {
                    'host': self.k8s_config.domain,
                    'http': {'paths': redis_paths}
                };
            } else {
                redis_rule = {'http': {'paths': redis_paths}};
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
                'spec': {'ingressClassName': ingress_class, 'rules': [redis_rule]}
            };
            try {
                networking_v1.replace_namespaced_ingress(
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

    """Start the NGINX controller (non-blocking). Call finish_ingress() later once other
    deployment steps are done to minimise wall-clock wait time."""
    def start_controller(
        app_name: str,
        namespace: str,
        cluster_env: str,
        apps_v1: Any,
        core_v1: Any,
        rbac_v1: Any,
        networking_v1: Any
    ) -> None {
        self._deploy_nginx_controller(
            app_name, namespace, cluster_env, apps_v1, core_v1, rbac_v1, networking_v1
        );
    }

    """Wait for the NGINX controller to be ready and then deploy routing rules.
    Must be called after start_controller()."""
    def finish_ingress(
        app_name: str,
        namespace: str,
        service_port: int,
        grafana_enabled: bool,
        redis_dashboard: bool,
        mongo_dashboard: bool,
        apps_v1: Any,
        core_v1: Any,
        networking_v1: Any
    ) -> None {
        self._wait_for_nginx_ready(app_name, namespace, apps_v1);
        self._deploy_ingress_resource(
            app_name,
            namespace,
            f"{namespace}-{app_name}-nginx",
            service_port,
            grafana_enabled,
            redis_dashboard,
            mongo_dashboard,
            networking_v1,
            core_v1
        );
    }

    """Deploy the full ingress stack: NGINX controller, wait for readiness, then routing rules."""
    def deploy(
        app_name: str,
        namespace: str,
        cluster_env: str,
        service_port: int,
        grafana_enabled: bool,
        redis_dashboard: bool,
        mongo_dashboard: bool,
        apps_v1: Any,
        core_v1: Any,
        rbac_v1: Any,
        networking_v1: Any
    ) -> None {
        self.start_controller(
            app_name, namespace, cluster_env, apps_v1, core_v1, rbac_v1, networking_v1
        );
        self.finish_ingress(
            app_name,
            namespace,
            service_port,
            grafana_enabled,
            redis_dashboard,
            mongo_dashboard,
            apps_v1,
            core_v1,
            networking_v1
        );
    }

    """Install cert-manager and create a namespace-scoped letsencrypt-prod Issuer.

    Idempotent: returns immediately if the Issuer already exists.
    Uses kubectl apply for the cert-manager manifests (CRD-safe) and the
    Kubernetes Python client for the Issuer resource.
    """
    def _install_cert_manager(
        app_name: str,
        namespace: str,
        cert_manager_email: str,
        core_v1: Any,
        apps_v1: Any,
        custom_api: Any
    ) -> None {
        # Idempotency: if Issuer already exists, nothing to do
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

        # Install cert-manager manifests if namespace not present
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

        # Wait for cert-manager webhook to be ready (up to 120 s)
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

        # Create namespace-scoped Issuer
        ingress_class_name = f"{namespace}-{app_name}-nginx";
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

    """Patch the existing Ingress(es) with TLS annotations and wait for the certificate.

    Must be called after _install_cert_manager(). Does not redeploy the application.
    """
    def enable_tls(
        app_name: str,
        namespace: str,
        networking_v1: Any,
        custom_api: Any,
        core_v1: Any,
        apps_v1: Any
    ) -> None {
        ingress_name = f"{app_name}-ingress";
        redis_ingress_name = f"{app_name}-redis-insight-ingress";
        tls_secret_name = f"{app_name}-tls";

        # Read domain / email from Ingress annotations (written during deploy)
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

        # Install cert-manager + create Issuer
        self._install_cert_manager(
            app_name, namespace, cert_email, core_v1, apps_v1, custom_api
        );

        # TLS patch applied to both Ingress resources
        tls_annotations = {
            'cert-manager.io/issuer': 'letsencrypt-prod',
            'nginx.ingress.kubernetes.io/ssl-redirect': 'true',
            'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
            'jac-scale/domain': domain
        };
        tls_spec = {'tls': [{'hosts': [domain], 'secretName': tls_secret_name}]};

        # Patch main Ingress: add TLS + set host on existing rules
        api_client = client.ApiClient();
        current_ingress = networking_v1.read_namespaced_ingress(
            name=ingress_name, namespace=namespace
        );
        ingress_dict = api_client.sanitize_for_serialization(current_ingress);
        existing_rules = ingress_dict.get('spec', {}).get('rules', []);
        updated_rules = [];
        for rule in existing_rules {
            rule['host'] = domain;
            updated_rules.append(rule);
        }
        tls_spec['rules'] = updated_rules;
        networking_v1.patch_namespaced_ingress(
            name=ingress_name,
            namespace=namespace,
            body={'metadata': {'annotations': tls_annotations}, 'spec': tls_spec}
        );
        if self.logger {
            self.logger.info(f"Patched '{ingress_name}' with TLS configuration");
        }

        # Patch RedisInsight Ingress if it exists (update its own rules with host)
        try {
            current_redis_ingress = networking_v1.read_namespaced_ingress(
                name=redis_ingress_name, namespace=namespace
            );
            redis_ingress_dict = api_client.sanitize_for_serialization(
                current_redis_ingress
            );
            existing_redis_rules = redis_ingress_dict.get('spec', {}).get('rules', []);
            updated_redis_rules = [];
            for rule in existing_redis_rules {
                rule['host'] = domain;
                updated_redis_rules.append(rule);
            }
            redis_tls_spec = {
                'tls': [{'hosts': [domain], 'secretName': tls_secret_name}],
                'rules': updated_redis_rules
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

        # Poll Certificate CRD until Ready=True (up to 300 s)
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

    """Tear down all ingress resources created by this deployer."""
    def destroy(
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        rbac_v1: Any,
        networking_v1: Any
    ) -> None {
        controller_name = f"{app_name}-ingress-nginx";
        cluster_resource_name = f"{namespace}-{app_name}-ingress-nginx";
        ingress_class_name = f"{namespace}-{app_name}-nginx";
        ingress_name = f"{app_name}-ingress";
        redis_ingress_name = f"{app_name}-redis-insight-ingress";
        service_name = f"{controller_name}-service";
        configmap_name = f"{app_name}-nginx-configuration";

        # Delete namespaced Ingress resources
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

        # Delete TLS secret, ACME private key, Certificate CRD, and Issuer
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

        # Delete controller namespaced resources
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

        # Delete cluster-scoped resources (no namespace parameter)
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

        if self.logger {
            self.logger.info(f"Ingress resources destroyed for '{app_name}'");
        }
    }
}
