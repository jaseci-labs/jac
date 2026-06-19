"""Prometheus and Grafana monitoring stack deployer for Kubernetes."""
import re;
import hashlib;
import from jac_scale._optdeps.kubernetes { client, ApiException }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    delete_if_exists,
    delete_k8s_secret
}
import from jac_scale.targets.kubernetes.cluster_provider { ClusterProvider }

"""Deploys and destroys a Prometheus + Grafana monitoring stack scoped to an app namespace.

Prometheus is always exposed as ClusterIP (internal, scraped by Grafana).
Grafana is exposed as ClusterIP, routed via NGINX Ingress at /grafana.

Admin credentials for Grafana use the 'prometheus_admin_password' config value.

Kubernetes metrics are collected via:
  - kube-state-metrics: exposes K8s object state (pods, deployments, replicas, restarts)
  - node-exporter:      exposes host-level metrics (CPU, memory, disk, network)
"""
obj MonitoringDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    """Deploy Prometheus ConfigMap with scrape config + Deployment + ClusterIP Service.

    Scrape targets include:
      - Jaseci application metrics at /metrics
      - kube-state-metrics for K8s object state (pods, deployments, replicas, restarts)
      - node-exporter for host-level node metrics (CPU, memory, disk, network)
    """
    def _deploy_prometheus(
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        provider: ClusterProvider
    ) {
        prometheus_name = f"{app_name}-prometheus";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        service_port = provider.prometheus_scrape_port(self.k8s_config.container_port);

        # The app's /metrics endpoint is admin-protected and also accepts Basic
        # Auth (admin username + prometheus_admin_password). Send those creds so
        # Prometheus can scrape without exposing /metrics unauthenticated.
        scrape_config = (
            "global:\n"
            "  scrape_interval: 15s\n"
            "  evaluation_interval: 15s\n"
            "scrape_configs:\n"
            f"  - job_name: '{app_name}'\n"
            "    static_configs:\n"
            f"      - targets: ['{app_name}-service:{service_port}']\n"
            "    metrics_path: '/metrics'\n"
            "    basic_auth:\n"
            f"      username: '{self.k8s_config.admin_username}'\n"
            # Read from a mounted Secret (see prometheus_scrape_secret below)
            # so the password stays out of the ConfigMap.
            "      password_file: /etc/prometheus/scrape-secret/password\n"
        );
        if self.k8s_config.k8s_metrics_enabled {
            scrape_config = scrape_config + (
                f"  - job_name: 'kube-state-metrics'\n"
                "    static_configs:\n"
                f"      - targets: ['{ksm_name}-service:8080']\n"
                "    metrics_path: '/metrics'\n"
                f"  - job_name: 'node-exporter'\n"
                "    static_configs:\n"
                f"      - targets: ['{ne_name}-service:9100']\n"
                "    metrics_path: '/metrics'\n"
            );
            # cAdvisor (per-container CPU/memory) is exposed by the kubelet, not a
            # standalone exporter. Scrape it through the API-server node proxy so we
            # don't need host-network access. Requires the prometheus ServiceAccount
            # to have nodes/proxy RBAC (granted below) and its token mounted.
            scrape_config = scrape_config + (
                "  - job_name: 'kubernetes-cadvisor'\n"
                "    scheme: https\n"
                "    tls_config:\n"
                "      insecure_skip_verify: true\n"
                "    authorization:\n"
                "      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n"
                "    kubernetes_sd_configs:\n"
                "      - role: node\n"
                "    relabel_configs:\n"
                "      - action: labelmap\n"
                "        regex: __meta_kubernetes_node_label_(.+)\n"
                "      - target_label: __address__\n"
                "        replacement: kubernetes.default.svc:443\n"
                "      - source_labels: [__meta_kubernetes_node_name]\n"
                "        regex: (.+)\n"
                "        target_label: __metrics_path__\n"
                "        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor\n"
            );
        }

        # Hash the scrape config so a pod-template annotation change triggers a rollout
        # whenever the scrape targets change (Kubernetes only rolls pods on spec changes).
        config_hash = hashlib.md5(scrape_config.encode()).hexdigest()[:12];

        prometheus_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{prometheus_name}-config",
                'namespace': namespace,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'data': {'prometheus.yml': scrape_config}
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{prometheus_name}-config", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{prometheus_name}-config",
                namespace=namespace,
                body=prometheus_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=prometheus_configmap
                );
            } else {
                raise;
            }
        }

        # Secret holding the scrape password, mounted into the pod and referenced
        # by basic_auth.password_file — keeps the credential out of the ConfigMap.
        scrape_secret_name = f"{prometheus_name}-scrape-secret";
        scrape_secret = {
            'apiVersion': 'v1',
            'kind': 'Secret',
            'metadata': {
                'name': scrape_secret_name,
                'namespace': namespace,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'type': 'Opaque',
            'stringData': {'password': self.k8s_config.prometheus_admin_password}
        };
        try {
            core_v1.read_namespaced_secret(
                name=scrape_secret_name, namespace=namespace
            );
            core_v1.replace_namespaced_secret(
                name=scrape_secret_name, namespace=namespace, body=scrape_secret
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_secret(
                    namespace=namespace, body=scrape_secret
                );
            } else {
                raise;
            }
        }

        prometheus_sa_name = f"{prometheus_name}-sa";
        # Token is automounted so Prometheus can authenticate to the API-server
        # node proxy when scraping cAdvisor (see scrape_config above).
        prometheus_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': prometheus_sa_name,
                'namespace': namespace,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': True
        };
        try {
            core_v1.read_namespaced_service_account(
                name=prometheus_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=prometheus_sa
                );
            } else {
                raise;
            }
        }

        # ClusterRole granting read access to node metrics + the cAdvisor proxy
        # path. Cluster-scoped because nodes are not namespaced. Prefixed with the
        # namespace so multiple deployments don't collide.
        prometheus_cluster_role_name = f"{namespace}-{prometheus_name}";
        prometheus_rbac_v1 = client.RbacAuthorizationV1Api();
        prometheus_cluster_role = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {
                'name': prometheus_cluster_role_name,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'rules': [
                {
                    'apiGroups': [''],
                    'resources': [
                        'nodes',
                        'nodes/proxy',
                        'nodes/metrics',
                        'services',
                        'endpoints',
                        'pods'
                    ],
                    'verbs': ['get', 'list', 'watch']
                },
                {'nonResourceURLs': ['/metrics', '/metrics/cadvisor'], 'verbs': ['get']}
            ]
        };
        try {
            prometheus_rbac_v1.read_cluster_role(name=prometheus_cluster_role_name);
            prometheus_rbac_v1.replace_cluster_role(
                name=prometheus_cluster_role_name, body=prometheus_cluster_role
            );
        } except ApiException as e {
            if e.status == 404 {
                prometheus_rbac_v1.create_cluster_role(body=prometheus_cluster_role);
            } else {
                raise;
            }
        }
        prometheus_crb = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRoleBinding',
            'metadata': {
                'name': prometheus_cluster_role_name,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'roleRef': {
                'apiGroup': 'rbac.authorization.k8s.io',
                'kind': 'ClusterRole',
                'name': prometheus_cluster_role_name
            },
            'subjects': [
                {
                    'kind': 'ServiceAccount',
                    'name': prometheus_sa_name,
                    'namespace': namespace
                }
            ]
        };
        try {
            prometheus_rbac_v1.read_cluster_role_binding(
                name=prometheus_cluster_role_name
            );
            prometheus_rbac_v1.replace_cluster_role_binding(
                name=prometheus_cluster_role_name, body=prometheus_crb
            );
        } except ApiException as e {
            if e.status == 404 {
                prometheus_rbac_v1.create_cluster_role_binding(body=prometheus_crb);
            } else {
                raise;
            }
        }

        prometheus_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': prometheus_name,
                'namespace': namespace,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': prometheus_name}},
                'template': {
                    'metadata': {
                        'labels': {'app': prometheus_name},
                        # Changing this annotation forces Kubernetes to roll new pods,
                        # which ensures Prometheus always loads the latest scrape config.
                        'annotations': {'checksum/config': config_hash}
                    },
                    'spec': {
                        'automountServiceAccountToken': True,
                        'serviceAccountName': prometheus_sa_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'prometheus',
                                'image': 'prom/prometheus:latest',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 65534,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': [
                                    '--config.file=/etc/prometheus/prometheus.yml',
                                    '--storage.tsdb.path=/prometheus',
                                    '--web.console.libraries=/usr/share/prometheus/console_libraries',
                                    '--web.console.templates=/usr/share/prometheus/consoles',
                                    # Enables POST /-/reload for hot config reload without restart
                                    '--web.enable-lifecycle'
                                ],
                                'ports': [{'containerPort': 9090}],
                                'volumeMounts': [
                                    {
                                        'name': 'prometheus-config-vol',
                                        'mountPath': '/etc/prometheus'
                                    },
                                    {
                                        'name': 'prometheus-scrape-secret',
                                        'mountPath': '/etc/prometheus/scrape-secret',
                                        'readOnly': True
                                    },
                                    {
                                        'name': 'prometheus-data',
                                        'mountPath': '/prometheus'
                                    },
                                    {'name': 'tmp', 'mountPath': '/tmp'}
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'prometheus-config-vol',
                                'configMap': {'name': f"{prometheus_name}-config"}
                            },
                            {
                                'name': 'prometheus-scrape-secret',
                                'secret': {'secretName': scrape_secret_name}
                            },
                            {'name': 'prometheus-data', 'emptyDir': {}},
                            {'name': 'tmp', 'emptyDir': {}}
                        ]
                    }
                }
            }
        };
        # Always patch so the config-hash annotation propagates and triggers a rollout
        # when the scrape config changes. Fall back to create on first deploy.
        try {
            apps_v1.patch_namespaced_deployment(
                name=prometheus_name, namespace=namespace, body=prometheus_deployment
            );
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=prometheus_deployment
                );
            } else {
                raise;
            }
        }

        # Prometheus is ClusterIP  Grafana scrapes it internally at prometheus-service:9090
        prometheus_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{prometheus_name}-service",
                'namespace': namespace,
                'labels': {'app': prometheus_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': prometheus_name},
                'ports': [{'protocol': 'TCP', 'port': 9090, 'targetPort': 9090}]
            }
        };
        try {
            core_v1.read_namespaced_service(
                name=f"{prometheus_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=prometheus_service
                );
            } else {
                raise;
            }
        }

        if self.logger {
            self.logger.info(f"Prometheus deployed for '{app_name}'");
        }
    }

    """Deploy kube-state-metrics: ServiceAccount, ClusterRole, ClusterRoleBinding, Deployment, Service.

    kube-state-metrics exposes K8s object state metrics (pod phases, deployment replicas,
    container restarts, resource requests/limits, etc.) at port 8080.
    A ClusterRole is required so it can list/watch cluster-wide resources.
    """
    def _deploy_kube_state_metrics(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) {
        ksm_name = f"{app_name}-kube-state-metrics";
        ksm_sa_name = f"{ksm_name}-sa";
        # Prefix with namespace to avoid conflicts across multiple deployments
        cluster_role_name = f"{namespace}-{ksm_name}";
        cluster_role_binding_name = f"{namespace}-{ksm_name}";
        rbac_v1 = client.RbacAuthorizationV1Api();

        # ServiceAccount
        sa_body = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': ksm_sa_name,
                'namespace': namespace,
                'labels': {'app': ksm_name, 'managed': 'jac-scale'}
            }
        };
        try {
            core_v1.read_namespaced_service_account(
                name=ksm_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=sa_body
                );
            } else {
                raise;
            }
        }

        # ClusterRole (cluster-scoped — grants read access to K8s resources)
        cluster_role_body = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {
                'name': cluster_role_name,
                'labels': {'app': ksm_name, 'managed': 'jac-scale'}
            },
            'rules': [
                {
                    'apiGroups': [''],
                    'resources': [
                        'configmaps',
                        'secrets',
                        'nodes',
                        'pods',
                        'services',
                        'resourcequotas',
                        'replicationcontrollers',
                        'limitranges',
                        'persistentvolumeclaims',
                        'persistentvolumes',
                        'namespaces',
                        'endpoints'
                    ],
                    'verbs': ['list', 'watch']
                },
                {
                    'apiGroups': ['apps'],
                    'resources': [
                        'statefulsets',
                        'daemonsets',
                        'deployments',
                        'replicasets'
                    ],
                    'verbs': ['list', 'watch']
                },
                {
                    'apiGroups': ['batch'],
                    'resources': ['cronjobs', 'jobs'],
                    'verbs': ['list', 'watch']
                },
                {
                    'apiGroups': ['autoscaling'],
                    'resources': ['horizontalpodautoscalers'],
                    'verbs': ['list', 'watch']
                },
                {
                    'apiGroups': ['policy'],
                    'resources': ['poddisruptionbudgets'],
                    'verbs': ['list', 'watch']
                },
                {
                    'apiGroups': ['storage.k8s.io'],
                    'resources': ['storageclasses', 'volumeattachments'],
                    'verbs': ['list', 'watch']
                }
            ]
        };
        try {
            rbac_v1.read_cluster_role(name=cluster_role_name);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role(body=cluster_role_body);
            } else {
                raise;
            }
        }

        # ClusterRoleBinding (cluster-scoped — binds ServiceAccount to ClusterRole)
        crb_body = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRoleBinding',
            'metadata': {
                'name': cluster_role_binding_name,
                'labels': {'app': ksm_name, 'managed': 'jac-scale'}
            },
            'roleRef': {
                'apiGroup': 'rbac.authorization.k8s.io',
                'kind': 'ClusterRole',
                'name': cluster_role_name
            },
            'subjects': [
                {'kind': 'ServiceAccount', 'name': ksm_sa_name, 'namespace': namespace}
            ]
        };
        try {
            rbac_v1.read_cluster_role_binding(name=cluster_role_binding_name);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role_binding(body=crb_body);
            } else {
                raise;
            }
        }

        # Deployment
        ksm_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': ksm_name,
                'namespace': namespace,
                'labels': {'app': ksm_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': ksm_name}},
                'template': {
                    'metadata': {'labels': {'app': ksm_name, 'managed': 'jac-scale'}},
                    'spec': {
                        'automountServiceAccountToken': True,
                        'serviceAccountName': ksm_sa_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'kube-state-metrics',
                                'image': 'registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 65534,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'ports': [
                                    {'containerPort': 8080, 'name': 'http-metrics'},
                                    {'containerPort': 8081, 'name': 'telemetry'}
                                ],
                                'readinessProbe': {
                                    'httpGet': {'path': '/healthz', 'port': 8080},
                                    'initialDelaySeconds': 5,
                                    'timeoutSeconds': 5
                                },
                                'livenessProbe': {
                                    'httpGet': {'path': '/healthz', 'port': 8080},
                                    'initialDelaySeconds': 5,
                                    'timeoutSeconds': 5
                                }
                            }
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.read_namespaced_deployment(name=ksm_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=ksm_deployment
                );
            } else {
                raise;
            }
        }

        # Service (ClusterIP) — Prometheus scrapes this at port 8080
        ksm_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{ksm_name}-service",
                'namespace': namespace,
                'labels': {'app': ksm_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': ksm_name},
                'ports': [
                    {
                        'name': 'http-metrics',
                        'protocol': 'TCP',
                        'port': 8080,
                        'targetPort': 8080
                    }
                ]
            }
        };
        try {
            core_v1.read_namespaced_service(
                name=f"{ksm_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=ksm_service
                );
            } else {
                raise;
            }
        }

        if self.logger {
            self.logger.info(f"kube-state-metrics deployed for '{app_name}'");
        }
    }

    """Deploy node-exporter as a DaemonSet + ClusterIP Service.

    node-exporter runs on every cluster node and exposes host-level metrics
    (CPU, memory, disk I/O, network) at port 9100. Host paths /proc, /sys, and /
    are volume-mounted so node-exporter can read them without hostNetwork — this
    ensures the pod gets a normal overlay IP and the ClusterIP service can route
    to it correctly.
    """
    def _deploy_node_exporter(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) {
        ne_name = f"{app_name}-node-exporter";

        ne_daemonset = {
            'apiVersion': 'apps/v1',
            'kind': 'DaemonSet',
            'metadata': {
                'name': ne_name,
                'namespace': namespace,
                'labels': {'app': ne_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'selector': {'matchLabels': {'app': ne_name}},
                'template': {
                    'metadata': {'labels': {'app': ne_name, 'managed': 'jac-scale'}},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'tolerations': [{'operator': 'Exists', 'effect': 'NoSchedule'}],
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'node-exporter',
                                'image': 'prom/node-exporter:v1.10.2',
                                # node-exporter reads host proc/sys paths — readOnlyRootFilesystem
                                # and allowPrivilegeEscalation are still hardened; capabilities
                                # are kept minimal (only SYS_TIME omitted as not needed).
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 65534,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': [
                                    '--path.procfs=/host/proc',
                                    '--path.sysfs=/host/sys'
                                ],
                                'ports': [{'containerPort': 9100, 'name': 'metrics'}],
                                'volumeMounts': [
                                    {
                                        'name': 'proc',
                                        'mountPath': '/host/proc',
                                        'readOnly': True
                                    },
                                    {
                                        'name': 'sys',
                                        'mountPath': '/host/sys',
                                        'readOnly': True
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {'name': 'proc', 'hostPath': {'path': '/proc'}},
                            {'name': 'sys', 'hostPath': {'path': '/sys'}}
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.read_namespaced_daemon_set(name=ne_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_daemon_set(
                    namespace=namespace, body=ne_daemonset
                );
            } else {
                raise;
            }
        }

        # Service (ClusterIP) — Prometheus scrapes this at port 9100
        ne_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{ne_name}-service",
                'namespace': namespace,
                'labels': {'app': ne_name}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': ne_name},
                'ports': [
                    {
                        'name': 'metrics',
                        'protocol': 'TCP',
                        'port': 9100,
                        'targetPort': 9100
                    }
                ]
            }
        };
        try {
            core_v1.read_namespaced_service(
                name=f"{ne_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(namespace=namespace, body=ne_service);
            } else {
                raise;
            }
        }

        if self.logger {
            self.logger.info(f"node-exporter deployed for '{app_name}'");
        }
    }

    """Deploy Grafana admin Secret, datasource ConfigMap, Deployment and Service.

    On AWS a dedicated LoadBalancer (NLB) is created on port 80.
    On non-AWS a NodePort is used.

    Two dashboards are provisioned:
      - jac-scale.json: Jaseci app HTTP metrics (requests, latency, errors)
      - k8s-metrics.json: Kubernetes cluster metrics (nodes, pods, deployments)
    """
    def _deploy_grafana(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        grafana_name = f"{app_name}-grafana";
        prometheus_name = f"{app_name}-prometheus";
        grafana_secret_name = f"{grafana_name}-secret";

        # Admin credentials password sourced from prometheus_admin_password config field
        grafana_secret = {
            'apiVersion': 'v1',
            'kind': 'Secret',
            'metadata': {
                'name': grafana_secret_name,
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'type': 'Opaque',
            'stringData': {
                'GF_SECURITY_ADMIN_USER': 'admin',
                'GF_SECURITY_ADMIN_PASSWORD': self.k8s_config.prometheus_admin_password
            }
        };
        try {
            core_v1.read_namespaced_secret(
                name=grafana_secret_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_secret(
                    namespace=namespace, body=grafana_secret
                );
            } else {
                raise;
            }
        }

        # Datasource ConfigMap Prometheus is always ClusterIP at port 9090
        prometheus_url = f"http://{prometheus_name}-service:9090";
        loki_name = f"{app_name}-loki";
        loki_url = f"http://{loki_name}-service:3100";
        datasource_yaml = (
            "apiVersion: 1\n"
            "datasources:\n"
            "  - name: Prometheus\n"
            "    uid: prometheus\n"
            "    type: prometheus\n"
            f"    url: {prometheus_url}\n"
            "    isDefault: true\n"
            "    access: proxy\n"
            "    editable: true\n"
        );
        if self.k8s_config.loki_enabled {
            datasource_yaml = datasource_yaml + (
                "  - name: Loki\n"
                "    uid: loki\n"
                "    type: loki\n"
                f"    url: {loki_url}\n"
                "    access: proxy\n"
                "    editable: true\n"
            );
        }
        # Tempo trace datasource. `tracesToLogsV2` (added when Loki is
        # present) enables the span -> logs pivot by trace_id.
        if self.k8s_config.tracing_enabled {
            tempo_name = f"{app_name}-tempo";
            tempo_url = f"http://{tempo_name}-service:3200";
            tempo_ds = (
                "  - name: Tempo\n"
                "    uid: tempo\n"
                "    type: tempo\n"
                f"    url: {tempo_url}\n"
                "    access: proxy\n"
                "    editable: true\n"
                "    jsonData:\n"
                "      nodeGraph:\n"
                "        enabled: true\n"
            );
            if self.k8s_config.loki_enabled {
                tempo_ds = tempo_ds + (
                    "      tracesToLogsV2:\n"
                    "        datasourceUid: loki\n"
                    "        filterByTraceID: true\n"
                    "        spanStartTimeShift: \"-1h\"\n"
                    "        spanEndTimeShift: \"1h\"\n"
                );
            }
            datasource_yaml = datasource_yaml + tempo_ds;
        }
        grafana_ds_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{grafana_name}-datasources",
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'data': {'datasource.yaml': datasource_yaml}
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{grafana_name}-datasources", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{grafana_name}-datasources",
                namespace=namespace,
                body=grafana_ds_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=grafana_ds_configmap
                );
            } else {
                raise;
            }
        }

        # Dashboard provider ConfigMap tells Grafana where to find dashboards
        dashboard_provider_yaml = (
            "apiVersion: 1\n"
            "providers:\n"
            "  - name: 'jac-scale'\n"
            "    orgId: 1\n"
            "    folder: 'Jac Scale'\n"
            "    type: file\n"
            "    disableDeletion: false\n"
            "    updateIntervalSeconds: 10\n"
            "    options:\n"
            "      path: /var/lib/grafana/dashboards\n"
        );
        grafana_provider_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{grafana_name}-dashboard-provider",
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'data': {'provider.yaml': dashboard_provider_yaml}
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{grafana_name}-dashboard-provider", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{grafana_name}-dashboard-provider",
                namespace=namespace,
                body=grafana_provider_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=grafana_provider_configmap
                );
            } else {
                raise;
            }
        }

        # Dashboard JSON ConfigMap pre-built panels matching the app's metrics.
        # The metric prefix is derived from the K8s namespace (same logic as
        # config_loader's sanitize_prometheus_namespace).
        pfx = re.sub(r'[^a-zA-Z0-9]', '_', namespace);
        pfx = re.sub(r'_+', '_', pfx).strip('_');
        if pfx and pfx[0].isdigit() {
            pfx = f"_{pfx}";
        }
        ds = '{"type":"prometheus","uid":"prometheus"}';

        # --- Jaseci app metrics dashboard ---
        app_dashboard_json = (
            '{"title":"Jac Scale - App Metrics","uid":"jac-scale-app",'
            '"schemaVersion":36,"refresh":"10s","time":{"from":"now-1h","to":"now"},'
            '"panels":['
            '{"id":1,"type":"timeseries","title":"HTTP Request Rate (req/s)",'
            '"gridPos":{"x":0,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (method,path)",'
            '"legendFormat":"{{method}} {{path}}",'
            f'"datasource":{ds}' + '}]},'
            '{"id":2,"type":"timeseries","title":"Error Rate (5xx req/s)",'
            '"gridPos":{"x":12,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total' + '{status_code=~\\"5..\\"}[1m]))",'
            '"legendFormat":"5xx errors",'
            f'"datasource":{ds}' + '}]},'
            '{"id":3,"type":"timeseries","title":"Request Latency p50/p95/p99",'
            '"gridPos":{"x":0,"y":8,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            f'"datasource":{ds},'
            '"targets":['
            f'{{"refId":"A","expr":"histogram_quantile(0.50,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
            f'"legendFormat":"p50","datasource":{ds}' + '},'
            f'{{"refId":"B","expr":"histogram_quantile(0.95,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
            f'"legendFormat":"p95","datasource":{ds}' + '},'
            f'{{"refId":"C","expr":"histogram_quantile(0.99,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
            f'"legendFormat":"p99","datasource":{ds}' + '}]},'
            '{"id":4,"type":"stat","title":"Active Requests",'
            '"gridPos":{"x":12,"y":8,"w":6,"h":8},'
            f'"datasource":{ds},'
            f'"targets":[{{"refId":"A","expr":"{pfx}_http_requests_in_progress",'
            f'"legendFormat":"active","datasource":{ds}' + '}]},'
            '{"id":5,"type":"timeseries","title":"Requests by Status Code",'
            '"gridPos":{"x":0,"y":16,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (status_code)",'
            f'"legendFormat":"{{{{status_code}}}}","datasource":{ds}' + '}]},'
            '{"id":6,"type":"timeseries","title":"Requests by Path",'
            '"gridPos":{"x":12,"y":16,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (path)",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}' + '}]},'
            '{"id":7,"type":"timeseries","title":"p95 Latency by Path",'
            '"gridPos":{"x":0,"y":24,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,path))",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}' + '}]},'
            '{"id":8,"type":"timeseries","title":"p95 Latency by Method",'
            '"gridPos":{"x":12,"y":24,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,method))",'
            f'"legendFormat":"{{{{method}}}}","datasource":{ds}' + '}]},'
            '{"id":9,"type":"timeseries","title":"Average Request Duration",'
            '"gridPos":{"x":0,"y":32,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"rate({pfx}_http_request_duration_seconds_sum[5m]) / rate({pfx}_http_request_duration_seconds_count[5m])",'
            f'"legendFormat":"avg latency","datasource":{ds}' + '}]},'
            '{"id":10,"type":"timeseries","title":"Average Latency per Path",'
            '"gridPos":{"x":12,"y":32,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_request_duration_seconds_sum[5m])) by (path) / sum(rate({pfx}_http_request_duration_seconds_count[5m])) by (path)",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}' + '}]},'
            '{"id":11,"type":"heatmap","title":"Request Duration Heatmap",'
            '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
            f'"datasource":{ds},'
            '"options":{"calculate":false,"yAxis":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(increase({pfx}_http_request_duration_seconds_bucket[1m])) by (le)",'
            '"format":"heatmap",'
            f'"legendFormat":"{{{{le}}}}","datasource":{ds}' + '}]}' ']}'
        );

        # --- Kubernetes cluster metrics dashboard ---
        k8s_dashboard_json = (
            '{"title":"Kubernetes Cluster Metrics","uid":"k8s-cluster",'
            '"schemaVersion":36,"refresh":"30s","time":{"from":"now-1h","to":"now"},'
            '"panels":['
            # Node CPU Usage (node-exporter)
            '{"id":1,"type":"timeseries","title":"Node CPU Usage (%)",'
            '"gridPos":{"x":0,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - avg(rate(node_cpu_seconds_total' + '{mode=\\"idle\\"}[5m])) by (instance)) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}' + '}]},'
            # Node Memory Usage (node-exporter)
            '{"id":2,"type":"timeseries","title":"Node Memory Usage (%)",'
            '"gridPos":{"x":12,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}' + '}]},'
            # Pod counts by phase (kube-state-metrics)
            '{"id":3,"type":"stat","title":"Running Pods",'
            '"gridPos":{"x":0,"y":8,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_status_phase' + '{phase=\\"Running\\"} == 1) or vector(0)",'
            f'"legendFormat":"Running","datasource":{ds}' + '}]},'
            '{"id":4,"type":"stat","title":"Pending Pods",'
            '"gridPos":{"x":6,"y":8,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_status_phase' + '{phase=\\"Pending\\"} == 1) or vector(0)",'
            f'"legendFormat":"Pending","datasource":{ds}' + '}]},'
            '{"id":5,"type":"stat","title":"Failed Pods",'
            '"gridPos":{"x":12,"y":8,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_status_phase' + '{phase=\\"Failed\\"} == 1) or vector(0)",'
            f'"legendFormat":"Failed","datasource":{ds}' + '}]},'
            # Deployment replica status (kube-state-metrics)
            '{"id":6,"type":"timeseries","title":"Deployment Available Replicas",'
            '"gridPos":{"x":0,"y":12,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"kube_deployment_status_replicas_available",'
            f'"legendFormat":"{{{{deployment}}}}","datasource":{ds}' + '}]},'
            # Pod container restarts (kube-state-metrics)
            '{"id":7,"type":"timeseries","title":"Pod Container Restarts (last 1h)",'
            '"gridPos":{"x":12,"y":12,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod) > 0",'
            f'"legendFormat":"{{{{pod}}}}","datasource":{ds}' + '}]},'
            # Node Disk I/O (node-exporter)
            '{"id":8,"type":"timeseries","title":"Node Disk Read/Write (Bps)",'
            '"gridPos":{"x":0,"y":20,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"Bps"}},'
            f'"datasource":{ds},'
            '"targets":['
            '{"refId":"A",'
            '"expr":"sum(rate(node_disk_read_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} read","datasource":{ds}' + '},'
            '{"refId":"B",'
            '"expr":"sum(rate(node_disk_written_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} write","datasource":{ds}' + '}]},'
            # Node Network I/O (node-exporter)
            '{"id":9,"type":"timeseries","title":"Node Network Receive/Transmit (Bps)",'
            '"gridPos":{"x":12,"y":20,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"Bps"}},'
            f'"datasource":{ds},'
            '"targets":['
            '{"refId":"A",'
            '"expr":"sum(rate(node_network_receive_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} rx","datasource":{ds}' + '},'
            '{"refId":"B",'
            '"expr":"sum(rate(node_network_transmit_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} tx","datasource":{ds}' + '}]},'
            # Pod CPU resource requests (kube-state-metrics)
            '{"id":10,"type":"timeseries","title":"Pod CPU Requests (cores)",'
            '"gridPos":{"x":0,"y":28,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests' + '{resource=\\"cpu\\"}) by (pod)",'
            f'"legendFormat":"{{{{pod}}}}","datasource":{ds}' + '}]},'
            # Pod Memory resource requests (kube-state-metrics)
            '{"id":11,"type":"timeseries","title":"Pod Memory Requests (bytes)",'
            '"gridPos":{"x":12,"y":28,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"bytes"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests' + '{resource=\\"memory\\"}) by (pod)",'
            f'"legendFormat":"{{{{pod}}}}","datasource":{ds}' + '}]},'
            # ── Node-level statistics ──────────────────────────────────────────
            # Total node count (kube-state-metrics)
            '{"id":12,"type":"stat","title":"Total Nodes",'
            '"gridPos":{"x":0,"y":36,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_node_info) or vector(0)",'
            f'"legendFormat":"nodes","datasource":{ds}' + '}]},'
            # Ready node count (kube-state-metrics)
            '{"id":13,"type":"stat","title":"Ready Nodes",'
            '"gridPos":{"x":6,"y":36,"w":6,"h":4},'
            '"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},'
            '"thresholds":{"steps":[{"color":"red","value":0},{"color":"green","value":1}]}}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_node_status_condition' + '{condition=\\"Ready\\",status=\\"true\\"} == 1) or vector(0)",'
            f'"legendFormat":"ready","datasource":{ds}' + '}]},'
            # Not-ready nodes alert stat
            '{"id":14,"type":"stat","title":"Not-Ready Nodes",'
            '"gridPos":{"x":12,"y":36,"w":6,"h":4},'
            '"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},'
            '"thresholds":{"steps":[{"color":"green","value":0},{"color":"red","value":1}]}}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_node_status_condition' + '{condition=\\"Ready\\",status=\\"false\\"} == 1) or vector(0)",'
            f'"legendFormat":"not-ready","datasource":{ds}' + '}]},'
            # Pods scheduled per node (kube-state-metrics)
            '{"id":15,"type":"timeseries","title":"Pods per Node",'
            '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_info' + '{node!=\\"\\"}) by (node)",'
            f'"legendFormat":"{{{{node}}}}","datasource":{ds}' + '}]},'
            # Node CPU usage % (node-exporter — per node)
            '{"id":16,"type":"timeseries","title":"Node CPU Usage (%) per Node",'
            '"gridPos":{"x":0,"y":48,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - avg(rate(node_cpu_seconds_total' + '{mode=\\"idle\\"}[5m])) by (instance)) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}' + '}]},'
            # Node memory usage % (node-exporter — per node)
            '{"id":17,"type":"timeseries","title":"Node Memory Usage (%) per Node",'
            '"gridPos":{"x":12,"y":48,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}' + '}]},'
            # CPU requests per node summed across all pods (kube-state-metrics)
            '{"id":18,"type":"timeseries","title":"CPU Requests per Node (cores)",'
            '"gridPos":{"x":0,"y":56,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests' + '{resource=\\"cpu\\"}) by (node)",'
            f'"legendFormat":"{{{{node}}}}","datasource":{ds}' + '}]},'
            # Memory requests per node summed across all pods (kube-state-metrics)
            '{"id":19,"type":"timeseries","title":"Memory Requests per Node (bytes)",'
            '"gridPos":{"x":12,"y":56,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"bytes"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests' + '{resource=\\"memory\\"}) by (node)",'
            f'"legendFormat":"{{{{node}}}}","datasource":{ds}' + '}]}' ']}'
        );

        lds = '{"type":"loki","uid":"loki"}';
        logs_dashboard_json = (
            '{"title":"Pod Logs","uid":"pod-logs",'
            '"schemaVersion":36,"refresh":"30s","time":{"from":"now-1h","to":"now"},'
            '"panels":['
            '{"id":1,"type":"timeseries","title":"Log Volume (lines/min)",'
            '"gridPos":{"x":0,"y":0,"w":24,"h":6},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{lds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(count_over_time({namespace=~\\".+\\"}[1m])) by (namespace,pod)",'
            f'"legendFormat":"{{{{namespace}}}}/{{{{pod}}}}","datasource":{lds}' + '}]},'
            '{"id":2,"type":"logs","title":"All Pod Logs",'
            '"gridPos":{"x":0,"y":6,"w":24,"h":20},'
            f'"datasource":{lds},'
            '"options":{"dedupStrategy":"none","showLabels":true,'
            '"showCommonLabels":false,"wrapLogMessage":true,"sortOrder":"Descending"},'
            '"targets":[{"refId":"A",'
            '"expr":"{namespace=~\\".+\\"}",'
            f'"datasource":{lds}' + '}]}]}'
        );

        dashboard_data: dict[str, str] = {'jac-scale.json': app_dashboard_json};
        if self.k8s_config.k8s_metrics_enabled {
            dashboard_data['k8s-metrics.json'] = k8s_dashboard_json;
        }
        if self.k8s_config.loki_enabled {
            dashboard_data['pod-logs.json'] = logs_dashboard_json;
        }

        grafana_dashboard_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{grafana_name}-dashboard",
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'data': dashboard_data
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{grafana_name}-dashboard", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{grafana_name}-dashboard",
                namespace=namespace,
                body=grafana_dashboard_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=grafana_dashboard_configmap
                );
            } else {
                raise;
            }
        }

        grafana_sa_name = f"{grafana_name}-sa";
        grafana_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': grafana_sa_name,
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': False
        };
        try {
            core_v1.read_namespaced_service_account(
                name=grafana_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=grafana_sa
                );
            } else {
                raise;
            }
        }

        grafana_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': grafana_name,
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': grafana_name}},
                'template': {
                    'metadata': {'labels': {'app': grafana_name}},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'serviceAccountName': grafana_sa_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'grafana',
                                'image': 'grafana/grafana:latest',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 472,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'ports': [{'containerPort': 3000}],
                                'envFrom': [
                                    {'secretRef': {'name': grafana_secret_name}}
                                ],
                                'env': [
                                    {
                                        'name': 'GF_SERVER_ROOT_URL',
                                        'value': f"http://{self.k8s_config.domain}/grafana"
                                            if self.k8s_config.domain
                                            else '%(protocol)s://%(domain)s/grafana'
                                    },
                                    {
                                        'name': 'GF_SERVER_SERVE_FROM_SUB_PATH',
                                        'value': 'true'
                                    }
                                ],
                                'volumeMounts': [
                                    {
                                        'name': 'grafana-datasources-vol',
                                        'mountPath': '/etc/grafana/provisioning/datasources'
                                    },
                                    {
                                        'name': 'grafana-dashboard-provider-vol',
                                        'mountPath': '/etc/grafana/provisioning/dashboards'
                                    },
                                    {
                                        'name': 'grafana-dashboard-vol',
                                        'mountPath': '/var/lib/grafana/dashboards'
                                    },
                                    {
                                        'name': 'grafana-data',
                                        'mountPath': '/var/lib/grafana'
                                    },
                                    {'name': 'tmp', 'mountPath': '/tmp'}
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'grafana-datasources-vol',
                                'configMap': {'name': f"{grafana_name}-datasources"}
                            },
                            {
                                'name': 'grafana-dashboard-provider-vol',
                                'configMap': {
                                    'name': f"{grafana_name}-dashboard-provider"
                                }
                            },
                            {
                                'name': 'grafana-dashboard-vol',
                                'configMap': {'name': f"{grafana_name}-dashboard"}
                            },
                            {'name': 'grafana-data', 'emptyDir': {}},
                            {'name': 'tmp', 'emptyDir': {}}
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.patch_namespaced_deployment(
                name=grafana_name, namespace=namespace, body=grafana_deployment
            );
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=grafana_deployment
                );
            } else {
                raise;
            }
        }

        # Service: always ClusterIP — exposed via NGINX Ingress at /grafana
        grafana_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{grafana_name}-service",
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': grafana_name},
                'ports': [{'protocol': 'TCP', 'port': 3000, 'targetPort': 3000}]
            }
        };

        try {
            core_v1.read_namespaced_service(
                name=f"{grafana_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=grafana_service
                );
            } else {
                raise;
            }
        }

        if self.logger {
            self.logger.info(
                f"Grafana deployed for '{app_name}' (ClusterIP, accessible via ingress at /grafana)"
            );
        }
    }

    """Deploy Tempo as a single-binary trace store.

    OTLP receivers on 4317/4318 (the Alloy collector exports spans here)
    and an HTTP API on 3200 for TraceQL search. emptyDir storage, so
    traces are ephemeral (suitable for dev/staging).
    """
    def _deploy_tempo(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        tempo_name = f"{app_name}-tempo";
        tempo_sa_name = f"{tempo_name}-sa";

        tempo_config_yaml = (
            "server:\n"
            "  http_listen_port: 3200\n"
            "distributor:\n"
            "  receivers:\n"
            "    otlp:\n"
            "      protocols:\n"
            "        grpc:\n"
            "          endpoint: 0.0.0.0:4317\n"
            "        http:\n"
            "          endpoint: 0.0.0.0:4318\n"
            "ingester:\n"
            "  trace_idle_period: 10s\n"
            "  max_block_duration: 5m\n"
            "compactor:\n"
            "  compaction:\n"
            "    block_retention: 48h\n"
            "storage:\n"
            "  trace:\n"
            "    backend: local\n"
            "    local:\n"
            "      path: /var/tempo/blocks\n"
            "    wal:\n"
            "      path: /var/tempo/wal\n"
            "usage_report:\n"
            "  reporting_enabled: false\n"
        );
        tempo_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{tempo_name}-config",
                'namespace': namespace,
                'labels': {'app': tempo_name, 'managed': 'jac-scale'}
            },
            'data': {'tempo.yaml': tempo_config_yaml}
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{tempo_name}-config", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{tempo_name}-config", namespace=namespace, body=tempo_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=tempo_configmap
                );
            } else {
                raise;
            }
        }

        tempo_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': tempo_sa_name,
                'namespace': namespace,
                'labels': {'app': tempo_name, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': False
        };
        try {
            core_v1.read_namespaced_service_account(
                name=tempo_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=tempo_sa
                );
            } else {
                raise;
            }
        }

        tempo_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': tempo_name,
                'namespace': namespace,
                'labels': {'app': tempo_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': tempo_name}},
                'template': {
                    'metadata': {'labels': {'app': tempo_name}},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'serviceAccountName': tempo_sa_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'tempo',
                                'image': 'grafana/tempo:2.7.0',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 10001,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': ['-config.file=/etc/tempo/tempo.yaml'],
                                'ports': [
                                    {'containerPort': 3200, 'name': 'http'},
                                    {'containerPort': 4317, 'name': 'otlp-grpc'},
                                    {'containerPort': 4318, 'name': 'otlp-http'}
                                ],
                                'readinessProbe': {
                                    'httpGet': {'path': '/ready', 'port': 3200},
                                    'initialDelaySeconds': 15,
                                    'timeoutSeconds': 5
                                },
                                'livenessProbe': {
                                    'httpGet': {'path': '/ready', 'port': 3200},
                                    'initialDelaySeconds': 15,
                                    'timeoutSeconds': 5
                                },
                                'volumeMounts': [
                                    {
                                        'name': 'tempo-config-vol',
                                        'mountPath': '/etc/tempo'
                                    },
                                    {'name': 'tempo-data', 'mountPath': '/var/tempo'},
                                    {'name': 'tmp', 'mountPath': '/tmp'}
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'tempo-config-vol',
                                'configMap': {'name': f"{tempo_name}-config"}
                            },
                            {'name': 'tempo-data', 'emptyDir': {}},
                            {'name': 'tmp', 'emptyDir': {}}
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.patch_namespaced_deployment(
                name=tempo_name, namespace=namespace, body=tempo_deployment
            );
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=tempo_deployment
                );
            } else {
                raise;
            }
        }

        tempo_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{tempo_name}-service",
                'namespace': namespace,
                'labels': {'app': tempo_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': tempo_name},
                'ports': [
                    {
                        'name': 'http',
                        'protocol': 'TCP',
                        'port': 3200,
                        'targetPort': 3200
                    },
                    {
                        'name': 'otlp-grpc',
                        'protocol': 'TCP',
                        'port': 4317,
                        'targetPort': 4317
                    },
                    {
                        'name': 'otlp-http',
                        'protocol': 'TCP',
                        'port': 4318,
                        'targetPort': 4318
                    }
                ]
            }
        };
        try {
            core_v1.read_namespaced_service(
                name=f"{tempo_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=tempo_service
                );
            } else {
                raise;
            }
        }

        if self.logger {
            self.logger.info(f"Tempo deployed for '{app_name}'");
        }
    }

    """Deploy Loki as a single-process log store.

    Loki is always ClusterIP — Grafana and Alloy talk to it internally.
    Data is stored in emptyDir so it is ephemeral (suitable for dev/staging).
    """
    def _deploy_loki(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        loki_name = f"{app_name}-loki";
        loki_sa_name = f"{loki_name}-sa";

        loki_config_yaml = (
            "auth_enabled: false\n"
            "server:\n"
            "  http_listen_port: 3100\n"
            "  grpc_listen_port: 9096\n"
            "common:\n"
            "  path_prefix: /loki\n"
            "  storage:\n"
            "    filesystem:\n"
            "      chunks_directory: /loki/chunks\n"
            "      rules_directory: /loki/rules\n"
            "  replication_factor: 1\n"
            "  ring:\n"
            "    instance_addr: 127.0.0.1\n"
            "    kvstore:\n"
            "      store: inmemory\n"
            "schema_config:\n"
            "  configs:\n"
            "    - from: 2020-10-24\n"
            "      store: tsdb\n"
            "      object_store: filesystem\n"
            "      schema: v13\n"
            "      index:\n"
            "        prefix: index_\n"
            "        period: 24h\n"
            "limits_config:\n"
            "  reject_old_samples: true\n"
            "  reject_old_samples_max_age: 168h\n"
        );
        loki_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{loki_name}-config",
                'namespace': namespace,
                'labels': {'app': loki_name, 'managed': 'jac-scale'}
            },
            'data': {'loki.yaml': loki_config_yaml}
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{loki_name}-config", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{loki_name}-config", namespace=namespace, body=loki_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=loki_configmap
                );
            } else {
                raise;
            }
        }

        loki_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': loki_sa_name,
                'namespace': namespace,
                'labels': {'app': loki_name, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': False
        };
        try {
            core_v1.read_namespaced_service_account(
                name=loki_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=loki_sa
                );
            } else {
                raise;
            }
        }

        loki_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': loki_name,
                'namespace': namespace,
                'labels': {'app': loki_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': loki_name}},
                'template': {
                    'metadata': {'labels': {'app': loki_name}},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'serviceAccountName': loki_sa_name,
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'loki',
                                'image': 'grafana/loki:3.4.2',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 10001,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': ['-config.file=/etc/loki/loki.yaml'],
                                'ports': [{'containerPort': 3100, 'name': 'http'}],
                                'readinessProbe': {
                                    'httpGet': {'path': '/ready', 'port': 3100},
                                    'initialDelaySeconds': 15,
                                    'timeoutSeconds': 5
                                },
                                'livenessProbe': {
                                    'httpGet': {'path': '/ready', 'port': 3100},
                                    'initialDelaySeconds': 15,
                                    'timeoutSeconds': 5
                                },
                                'volumeMounts': [
                                    {
                                        'name': 'loki-config-vol',
                                        'mountPath': '/etc/loki'
                                    },
                                    {'name': 'loki-data', 'mountPath': '/loki'},
                                    {'name': 'tmp', 'mountPath': '/tmp'}
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'loki-config-vol',
                                'configMap': {'name': f"{loki_name}-config"}
                            },
                            {'name': 'loki-data', 'emptyDir': {}},
                            {'name': 'tmp', 'emptyDir': {}}
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.patch_namespaced_deployment(
                name=loki_name, namespace=namespace, body=loki_deployment
            );
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=loki_deployment
                );
            } else {
                raise;
            }
        }

        loki_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{loki_name}-service",
                'namespace': namespace,
                'labels': {'app': loki_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': loki_name},
                'ports': [{'protocol': 'TCP', 'port': 3100, 'targetPort': 3100}]
            }
        };
        try {
            core_v1.read_namespaced_service(
                name=f"{loki_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=loki_service
                );
            } else {
                raise;
            }
        }

        if self.logger {
            self.logger.info(f"Loki deployed for '{app_name}'");
        }
    }

    """Deploy Grafana Alloy as a DaemonSet for logs and/or traces.

    Tails pod logs to Loki and/or receives OTLP spans and forwards them
    to Tempo, depending on which signals are enabled. River-syntax config.
    """
    def _deploy_alloy(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        loki_name = f"{app_name}-loki";
        alloy_name = f"{app_name}-alloy";
        alloy_sa_name = f"{alloy_name}-sa";
        cluster_role_name = f"{namespace}-{alloy_name}";
        cluster_role_binding_name = f"{namespace}-{alloy_name}";
        rbac_v1 = client.RbacAuthorizationV1Api();
        loki_push_url = f"http://{loki_name}-service:3100/loki/api/v1/push";
        tempo_name = f"{app_name}-tempo";
        tempo_otlp_endpoint = f"{tempo_name}-service:4317";

        # River pipeline: a header plus two optional lanes - the logs lane
        # (loki_enabled) and the OTLP traces lane (tracing_enabled).
        alloy_header = (
            "logging {\n" "  level  = \"info\"\n" "  format = \"logfmt\"\n" "}\n" "\n"
        );

        # Logs lane: discover pods, relabel to per-container log paths under
        # /var/log/pods, tail them, parse the CRI wrapper, push to Loki.
        alloy_logs_lane = (
            "discovery.kubernetes \"pods\" {\n"
            "  role = \"pod\"\n"
            "}\n"
            "\n"
            "discovery.relabel \"pods\" {\n"
            "  targets = discovery.kubernetes.pods.targets\n"
            "\n"
            "  rule {\n"
            "    source_labels = [\"__meta_kubernetes_pod_node_name\"]\n"
            "    target_label  = \"__host__\"\n"
            "  }\n"
            "\n"
            "  rule {\n"
            "    action = \"labelmap\"\n"
            "    regex  = \"__meta_kubernetes_pod_label_(.+)\"\n"
            "  }\n"
            "\n"
            "  rule {\n"
            "    source_labels = [\"__meta_kubernetes_namespace\"]\n"
            "    target_label  = \"namespace\"\n"
            "  }\n"
            "\n"
            "  rule {\n"
            "    source_labels = [\"__meta_kubernetes_pod_name\"]\n"
            "    target_label  = \"pod\"\n"
            "  }\n"
            "\n"
            "  rule {\n"
            "    source_labels = [\"__meta_kubernetes_pod_container_name\"]\n"
            "    target_label  = \"container\"\n"
            "  }\n"
            "\n"
            "  rule {\n"
            "    action        = \"replace\"\n"
            "    separator     = \"/\"\n"
            "    source_labels = [\n"
            "      \"__meta_kubernetes_pod_uid\",\n"
            "      \"__meta_kubernetes_pod_container_name\",\n"
            "    ]\n"
            "    target_label = \"__path__\"\n"
            "    replacement  = \"/var/log/pods/*$1/*.log\"\n"
            "  }\n"
            "}\n"
            "\n"
            "local.file_match \"pods\" {\n"
            "  path_targets = discovery.relabel.pods.output\n"
            "}\n"
            "\n"
            "loki.source.file \"pods\" {\n"
            "  targets    = local.file_match.pods.targets\n"
            "  forward_to = [loki.process.cri.receiver]\n"
            "}\n"
            "\n"
            "loki.process \"cri\" {\n"
            "  forward_to = [loki.write.default.receiver]\n"
            "\n"
            "  // Strip the containerd CRI wrapper (timestamp + stream + tag\n"
            "  // + content). After this stage the line body is whatever the\n"
            "  // app wrote to stdout.\n"
            "  stage.cri {}\n"
            "\n"
            "  // Lift top-level keys out of structured-JSON log lines.\n"
            "  // Non-JSON lines fall through unmolested (variables stay unset).\n"
            "  stage.json {\n"
            "    expressions = {\n"
            "      ts       = \"ts\",\n"
            "      level    = \"level\",\n"
            "      service  = \"service\",\n"
            "      trace_id = \"trace_id\",\n"
            "    }\n"
            "  }\n"
            "\n"
            "  // Use the app-emitted timestamp when present (defends against\n"
            "  // node clock skew); lines without a valid ts keep the agent's.\n"
            "  stage.timestamp {\n"
            "    source            = \"ts\"\n"
            "    format            = \"RFC3339Nano\"\n"
            "    action_on_failure = \"skip\"\n"
            "  }\n"
            "\n"
            "  // Promote bounded-cardinality fields to Loki labels. trace_id\n"
            "  // is deliberately NOT a label (one stream per request); query\n"
            "  // it via `{namespace=ns} | json | trace_id=\"...\"`.\n"
            "  stage.labels {\n"
            "    values = {\n"
            "      service = \"\",\n"
            "      level   = \"\",\n"
            "    }\n"
            "  }\n"
            "}\n"
            "\n"
            "loki.write \"default\" {\n"
            "  endpoint {\n"
            f"    url = \"{loki_push_url}\"\n"
            "  }\n"
            "}\n"
        );
        # Drop the logs lane entirely when Loki is off (tracing-only
        # deploy): no point tailing pods if there's nowhere to ship them.
        if not self.k8s_config.loki_enabled {
            alloy_logs_lane = "";
        }

        # Traces lane: receive OTLP from app pods, batch, export to Tempo.
        alloy_otel_lane = "";
        if self.k8s_config.tracing_enabled {
            alloy_otel_lane = (
                "\n"
                "otelcol.receiver.otlp \"default\" {\n"
                "  grpc { endpoint = \"0.0.0.0:4317\" }\n"
                "  http { endpoint = \"0.0.0.0:4318\" }\n"
                "  output {\n"
                "    traces = [otelcol.processor.batch.default.input]\n"
                "  }\n"
                "}\n"
                "\n"
                "otelcol.processor.batch \"default\" {\n"
                "  output {\n"
                "    traces = [otelcol.exporter.otlp.tempo.input]\n"
                "  }\n"
                "}\n"
                "\n"
                "otelcol.exporter.otlp \"tempo\" {\n"
                "  client {\n"
                f"    endpoint = \"{tempo_otlp_endpoint}\"\n"
                "    tls { insecure = true }\n"
                "  }\n"
                "}\n"
            );
        }

        alloy_config_river = alloy_header + alloy_logs_lane + alloy_otel_lane;
        alloy_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{alloy_name}-config",
                'namespace': namespace,
                'labels': {'app': alloy_name, 'managed': 'jac-scale'}
            },
            'data': {'config.alloy': alloy_config_river}
        };
        try {
            core_v1.read_namespaced_config_map(
                name=f"{alloy_name}-config", namespace=namespace
            );
            core_v1.replace_namespaced_config_map(
                name=f"{alloy_name}-config", namespace=namespace, body=alloy_configmap
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=alloy_configmap
                );
            } else {
                raise;
            }
        }

        alloy_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': alloy_sa_name,
                'namespace': namespace,
                'labels': {'app': alloy_name, 'managed': 'jac-scale'}
            }
        };
        try {
            core_v1.read_namespaced_service_account(
                name=alloy_sa_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=alloy_sa
                );
            } else {
                raise;
            }
        }

        cluster_role_body = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {
                'name': cluster_role_name,
                'labels': {'app': alloy_name, 'managed': 'jac-scale'}
            },
            'rules': [
                {
                    'apiGroups': [''],
                    'resources': [
                        'nodes',
                        'nodes/proxy',
                        'pods',
                        'namespaces',
                        'services',
                        'endpoints'
                    ],
                    'verbs': ['get', 'watch', 'list']
                }
            ]
        };
        try {
            rbac_v1.read_cluster_role(name=cluster_role_name);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role(body=cluster_role_body);
            } else {
                raise;
            }
        }

        crb_body = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRoleBinding',
            'metadata': {
                'name': cluster_role_binding_name,
                'labels': {'app': alloy_name, 'managed': 'jac-scale'}
            },
            'roleRef': {
                'apiGroup': 'rbac.authorization.k8s.io',
                'kind': 'ClusterRole',
                'name': cluster_role_name
            },
            'subjects': [
                {
                    'kind': 'ServiceAccount',
                    'name': alloy_sa_name,
                    'namespace': namespace
                }
            ]
        };
        try {
            rbac_v1.read_cluster_role_binding(name=cluster_role_binding_name);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role_binding(body=crb_body);
            } else {
                raise;
            }
        }

        # Base agent port; add the OTLP receiver ports when tracing is on
        # so app pods can send spans to this Alloy via the Alloy Service.
        alloy_ports = [{'containerPort': 12345, 'name': 'http'}];
        if self.k8s_config.tracing_enabled {
            alloy_ports.append({'containerPort': 4317, 'name': 'otlp-grpc'});
            alloy_ports.append({'containerPort': 4318, 'name': 'otlp-http'});
        }

        alloy_daemonset = {
            'apiVersion': 'apps/v1',
            'kind': 'DaemonSet',
            'metadata': {
                'name': alloy_name,
                'namespace': namespace,
                'labels': {'app': alloy_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'selector': {'matchLabels': {'app': alloy_name}},
                'template': {
                    'metadata': {'labels': {'app': alloy_name, 'managed': 'jac-scale'}},
                    'spec': {
                        'automountServiceAccountToken': True,
                        'serviceAccountName': alloy_sa_name,
                        'tolerations': [{'operator': 'Exists', 'effect': 'NoSchedule'}],
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'alloy',
                                'image': 'grafana/alloy:v1.6.0',
                                'securityContext': {
                                    # /var/log/pods is root-owned on the
                                    # node so the agent runs as root with
                                    # all capabilities dropped. Same
                                    # hardening Promtail used in #5731.
                                    'runAsUser': 0,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': [
                                    'run',
                                    '--server.http.listen-addr=0.0.0.0:12345',
                                    # Use container /tmp as the WAL + remotecfg
                                    # scratch path instead of a mounted volume.
                                    # /tmp is always tmpfs-writable for any UID,
                                    # which sidesteps an Alloy v1.6 startup quirk
                                    # where the remotecfg service mkdir under a
                                    # mounted emptyDir fails with EACCES even
                                    # when the container runs as root with the
                                    # dir mode 0777. Validated on EKS m14a
                                    # deploy 2026-05-20 (13/13 pods Ready after
                                    # this swap).
                                    '--storage.path=/tmp/alloy',
                                    '/etc/alloy/config.alloy'
                                ],
                                'ports': alloy_ports,
                                'volumeMounts': [
                                    {
                                        'name': 'alloy-config-vol',
                                        'mountPath': '/etc/alloy'
                                    },
                                    {
                                        'name': 'varlogpods',
                                        'mountPath': '/var/log/pods',
                                        'readOnly': True
                                    },
                                    {
                                        # `/var/log/pods/<...>/<container>/<N>.log`
                                        # is a symlink chain pointing into the
                                        # container runtime's data dir (docker:
                                        # /var/lib/docker/containers, also where
                                        # minikube + EKS docker-shim land). Without
                                        # this mount the symlink follow fails with
                                        # ENOENT and Alloy logs
                                        # `error getting os stat ... no such file
                                        # or directory` every scrape interval. On
                                        # pure-containerd clusters the dir does
                                        # not exist; hostPath silently no-ops.
                                        # Validated on EKS 2026-05-20 + minikube.
                                        'name': 'varlogcontainers',
                                        'mountPath': '/var/lib/docker/containers',
                                        'readOnly': True
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'alloy-config-vol',
                                'configMap': {'name': f"{alloy_name}-config"}
                            },
                            {
                                'name': 'varlogpods',
                                'hostPath': {'path': '/var/log/pods'}
                            },
                            {
                                'name': 'varlogcontainers',
                                'hostPath': {'path': '/var/lib/docker/containers'}
                            }
                        ]
                    }
                }
            }
        };
        try {
            apps_v1.read_namespaced_daemon_set(name=alloy_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_daemon_set(
                    namespace=namespace, body=alloy_daemonset
                );
            } else {
                raise;
            }
        }

        # ClusterIP Service in front of the Alloy DaemonSet so app pods
        # have a stable OTLP target (`<app>-alloy-service:4318`). Only the
        # traces leg needs an inbound Service (logs push outbound to Loki).
        if self.k8s_config.tracing_enabled {
            alloy_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{alloy_name}-service",
                    'namespace': namespace,
                    'labels': {'app': alloy_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'type': 'ClusterIP',
                    'selector': {'app': alloy_name},
                    'ports': [
                        {
                            'name': 'otlp-grpc',
                            'protocol': 'TCP',
                            'port': 4317,
                            'targetPort': 4317
                        },
                        {
                            'name': 'otlp-http',
                            'protocol': 'TCP',
                            'port': 4318,
                            'targetPort': 4318
                        }
                    ]
                }
            };
            try {
                core_v1.read_namespaced_service(
                    name=f"{alloy_name}-service", namespace=namespace
                );
            } except ApiException as e {
                if e.status == 404 {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=alloy_service
                    );
                } else {
                    raise;
                }
            }
        }

        if self.logger {
            self.logger.info(f"Alloy deployed for '{app_name}'");
        }
    }

    """Deploy the full monitoring stack (Prometheus, kube-state-metrics, node-exporter, Grafana) for an app namespace."""
    def deploy(
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        provider: ClusterProvider
    ) -> None {
        if not self.k8s_config.monitoring_enabled {
            return;
        }

        if self.k8s_config.k8s_metrics_enabled {
            self._deploy_kube_state_metrics(app_name, namespace, apps_v1, core_v1);
            self._deploy_node_exporter(app_name, namespace, apps_v1, core_v1);
        }
        self._deploy_prometheus(app_name, namespace, apps_v1, core_v1, provider);
        if self.k8s_config.tracing_enabled {
            self._deploy_tempo(app_name, namespace, apps_v1, core_v1);
        }
        if self.k8s_config.loki_enabled {
            self._deploy_loki(app_name, namespace, apps_v1, core_v1);
        }
        # Alloy serves both legs (logs to Loki, traces to Tempo); deploy it
        # when either is on - its River config is built from both flags.
        if self.k8s_config.loki_enabled or self.k8s_config.tracing_enabled {
            self._deploy_alloy(app_name, namespace, apps_v1, core_v1);
        }
        self._deploy_grafana(app_name, namespace, apps_v1, core_v1);
    }

    """Destroy all monitoring resources: Prometheus, Grafana, kube-state-metrics, node-exporter, Loki, Alloy."""
    def destroy(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        prometheus_name = f"{app_name}-prometheus";
        grafana_name = f"{app_name}-grafana";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        loki_name = f"{app_name}-loki";
        alloy_name = f"{app_name}-alloy";
        cluster_role_name = f"{namespace}-{ksm_name}";
        cluster_role_binding_name = f"{namespace}-{ksm_name}";
        prometheus_cluster_role_name = f"{namespace}-{prometheus_name}";

        # Prometheus resources
        delete_if_exists(
            apps_v1.delete_namespaced_deployment,
            prometheus_name,
            namespace,
            'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{prometheus_name}-service",
            namespace,
            'Service'
        );
        try {
            core_v1.delete_namespaced_config_map(
                name=f"{prometheus_name}-config", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        delete_k8s_secret(core_v1, namespace, f"{prometheus_name}-scrape-secret");
        try {
            core_v1.delete_namespaced_service_account(
                name=f"{prometheus_name}-sa", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # kube-state-metrics resources
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, ksm_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{ksm_name}-service",
            namespace,
            'Service'
        );
        try {
            core_v1.delete_namespaced_service_account(
                name=f"{ksm_name}-sa", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        # ClusterRole and ClusterRoleBinding are cluster-scoped (no namespace param)
        rbac_v1 = client.RbacAuthorizationV1Api();
        try {
            rbac_v1.delete_cluster_role(name=cluster_role_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            rbac_v1.delete_cluster_role_binding(name=cluster_role_binding_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        # Prometheus cAdvisor RBAC (cluster-scoped)
        try {
            rbac_v1.delete_cluster_role(name=prometheus_cluster_role_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            rbac_v1.delete_cluster_role_binding(name=prometheus_cluster_role_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        # node-exporter resources (DaemonSet)
        try {
            apps_v1.delete_namespaced_daemon_set(name=ne_name, namespace=namespace);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{ne_name}-service",
            namespace,
            'Service'
        );

        # Loki resources
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, loki_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{loki_name}-service",
            namespace,
            'Service'
        );
        try {
            core_v1.delete_namespaced_config_map(
                name=f"{loki_name}-config", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            core_v1.delete_namespaced_service_account(
                name=f"{loki_name}-sa", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # Alloy resources
        try {
            apps_v1.delete_namespaced_daemon_set(name=alloy_name, namespace=namespace);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            core_v1.delete_namespaced_config_map(
                name=f"{alloy_name}-config", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            core_v1.delete_namespaced_service_account(
                name=f"{alloy_name}-sa", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        # The Alloy OTLP Service (only present in traces deploys).
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{alloy_name}-service",
            namespace,
            'Service'
        );
        alloy_cr_name = f"{namespace}-{alloy_name}";
        try {
            rbac_v1.delete_cluster_role(name=alloy_cr_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            rbac_v1.delete_cluster_role_binding(name=alloy_cr_name);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # Tempo resources. Deleted by name unconditionally so teardown is
        # idempotent regardless of the tracing toggle state.
        tempo_name = f"{app_name}-tempo";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, tempo_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{tempo_name}-service",
            namespace,
            'Service'
        );
        try {
            core_v1.delete_namespaced_config_map(
                name=f"{tempo_name}-config", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            core_v1.delete_namespaced_service_account(
                name=f"{tempo_name}-sa", namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # Grafana resources
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, grafana_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{grafana_name}-service",
            namespace,
            'Service'
        );
        for cm_name in [
            f"{grafana_name}-datasources",
            f"{grafana_name}-dashboard-provider",
            f"{grafana_name}-dashboard"
        ] {
            try {
                core_v1.delete_namespaced_config_map(name=cm_name, namespace=namespace);
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }
        }
        delete_k8s_secret(core_v1, namespace, f"{grafana_name}-secret");
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{prometheus_name}-sa",
            namespace,
            'ServiceAccount'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{grafana_name}-sa",
            namespace,
            'ServiceAccount'
        );

        if self.logger {
            self.logger.info(f"Monitoring stack destroyed for '{app_name}'");
        }
    }
}
