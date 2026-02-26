"""Prometheus and Grafana monitoring stack deployer for Kubernetes."""
import re;
import hashlib;
import from typing { Any }
import from kubernetes { client }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    delete_if_exists,
    delete_k8s_secret
}
import from kubernetes.client.exceptions { ApiException }

"""Deploys and destroys a Prometheus + Grafana monitoring stack scoped to an app namespace.

Prometheus is always exposed as ClusterIP (internal scraped by Grafana).
Grafana is exposed as:
  - NodePort      (non-AWS): accessible via <node-ip>:<grafana_node_port>
  - LoadBalancer  (AWS):     its own NLB, accessible at <grafana-nlb-url> (port 80)

Admin credentials for Grafana use the 'prometheus_admin_password' config value.

Kubernetes metrics are collected via:
  - kube-state-metrics: exposes K8s object state (pods, deployments, replicas, restarts)
  - node-exporter:      exposes host-level metrics (CPU, memory, disk, network)
"""
class MonitoringDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    def init(
        self: MonitoringDeployer,
        k8s_config: KubernetesConfig,
        logger: (Logger | None) = None
    ) -> None {
        self.k8s_config = k8s_config;
        self.logger = logger;
    }

    """Deploy Prometheus ConfigMap with scrape config + Deployment + ClusterIP Service.

    Scrape targets include:
      - Jaseci application metrics at /metrics
      - kube-state-metrics for K8s object state (pods, deployments, replicas, restarts)
      - node-exporter for host-level node metrics (CPU, memory, disk, network)
    """
    def _deploy_prometheus(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        cluster_env: str
    ) -> None {
        prometheus_name = f"{app_name}-prometheus";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        # Use the service port (80 on AWS LoadBalancer, container_port on local NodePort)
        service_port = 80 if cluster_env == 'aws' else self.k8s_config.container_port;

        scrape_config = (
            "global:\n"
            "  scrape_interval: 15s\n"
            "  evaluation_interval: 15s\n"
            "scrape_configs:\n"
            f"  - job_name: '{app_name}'\n"
            "    static_configs:\n"
            f"      - targets: ['{app_name}-service:{service_port}']\n"
            "    metrics_path: '/metrics'\n"
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
                raise ;
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
                        'containers': [
                            {
                                'name': 'prometheus',
                                'image': 'prom/prometheus:latest',
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
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'prometheus-config-vol',
                                'configMap': {'name': f"{prometheus_name}-config"}
                            }
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
                raise ;
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
                raise ;
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
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any
    ) -> None {
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
                'labels': {'app': ksm_name}
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
                raise ;
            }
        }

        # ClusterRole (cluster-scoped — grants read access to K8s resources)
        cluster_role_body = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {'name': cluster_role_name, 'labels': {'app': ksm_name}},
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
                raise ;
            }
        }

        # ClusterRoleBinding (cluster-scoped — binds ServiceAccount to ClusterRole)
        crb_body = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRoleBinding',
            'metadata': {
                'name': cluster_role_binding_name,
                'labels': {'app': ksm_name}
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
                raise ;
            }
        }

        # Deployment
        ksm_deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': ksm_name,
                'namespace': namespace,
                'labels': {'app': ksm_name}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': ksm_name}},
                'template': {
                    'metadata': {'labels': {'app': ksm_name}},
                    'spec': {
                        'serviceAccountName': ksm_sa_name,
                        'containers': [
                            {
                                'name': 'kube-state-metrics',
                                'image': 'registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1',
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
                raise ;
            }
        }

        # Service (ClusterIP) — Prometheus scrapes this at port 8080
        ksm_service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{ksm_name}-service",
                'namespace': namespace,
                'labels': {'app': ksm_name}
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
                raise ;
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
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any
    ) -> None {
        ne_name = f"{app_name}-node-exporter";

        ne_daemonset = {
            'apiVersion': 'apps/v1',
            'kind': 'DaemonSet',
            'metadata': {
                'name': ne_name,
                'namespace': namespace,
                'labels': {'app': ne_name}
            },
            'spec': {
                'selector': {'matchLabels': {'app': ne_name}},
                'template': {
                    'metadata': {'labels': {'app': ne_name}},
                    'spec': {
                        'tolerations': [{'operator': 'Exists', 'effect': 'NoSchedule'}],
                        'containers': [
                            {
                                'name': 'node-exporter',
                                'image': 'prom/node-exporter:v1.10.2',
                                'args': [
                                    '--path.procfs=/host/proc',
                                    '--path.sysfs=/host/sys',
                                    '--path.rootfs=/host/root'
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
                                    },
                                    {
                                        'name': 'root',
                                        'mountPath': '/host/root',
                                        'readOnly': True,
                                        'mountPropagation': 'HostToContainer'
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {'name': 'proc', 'hostPath': {'path': '/proc'}},
                            {'name': 'sys', 'hostPath': {'path': '/sys'}},
                            {'name': 'root', 'hostPath': {'path': '/'}}
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
                raise ;
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
                raise ;
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
    def _deploy_grafana(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        cluster_env: str
    ) -> None {
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
                raise ;
            }
        }

        # Datasource ConfigMap Prometheus is always ClusterIP at port 9090
        prometheus_url = f"http://{prometheus_name}-service:9090";
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
                raise ;
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
                raise ;
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

        grafana_dashboard_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{grafana_name}-dashboard",
                'namespace': namespace,
                'labels': {'app': grafana_name, 'managed': 'jac-scale'}
            },
            'data': (
                {
                    'jac-scale.json': app_dashboard_json,
                    'k8s-metrics.json': k8s_dashboard_json
                }
                    if self.k8s_config.k8s_metrics_enabled
                    else {'jac-scale.json': app_dashboard_json}
            )
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
                raise ;
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
                        'containers': [
                            {
                                'name': 'grafana',
                                'image': 'grafana/grafana:latest',
                                'ports': [{'containerPort': 3000}],
                                'envFrom': [
                                    {'secretRef': {'name': grafana_secret_name}}
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
                                    }
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
                            }
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
                raise ;
            }
        }

        # Service: NodePort locally, dedicated LoadBalancer (NLB) on AWS
        if cluster_env == 'aws' {
            grafana_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{grafana_name}-service",
                    'namespace': namespace,
                    'labels': {'app': grafana_name, 'managed': 'jac-scale'},
                    'annotations': {
                        'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb'
                    }
                },
                'spec': {
                    'type': 'LoadBalancer',
                    'selector': {'app': grafana_name},
                    'ports': [{'protocol': 'TCP', 'port': 80, 'targetPort': 3000}]
                }
            };
        } else {
            grafana_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{grafana_name}-service",
                    'namespace': namespace,
                    'labels': {'app': grafana_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'type': 'NodePort',
                    'selector': {'app': grafana_name},
                    'ports': [
                        {
                            'protocol': 'TCP',
                            'port': 3000,
                            'targetPort': 3000,
                            'nodePort': self.k8s_config.grafana_node_port
                        }
                    ]
                }
            };
        }

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
                raise ;
            }
        }

        if self.logger {
            if cluster_env == 'aws' {
                self.logger.info(f"Grafana deployed for '{app_name}'");
            } else {
                self.logger.info(
                    f"Grafana deployed for '{app_name}' accessible at localhost:{self.k8s_config.grafana_node_port}"
                );
            }
        }
    }

    """Deploy the full monitoring stack (Prometheus, kube-state-metrics, node-exporter, Grafana) for an app namespace."""
    def deploy(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        cluster_env: str
    ) -> None {
        if not self.k8s_config.monitoring_enabled {
            return;
        }

        if self.k8s_config.k8s_metrics_enabled {
            self._deploy_kube_state_metrics(app_name, namespace, apps_v1, core_v1);
            self._deploy_node_exporter(app_name, namespace, apps_v1, core_v1);
        }
        self._deploy_prometheus(app_name, namespace, apps_v1, core_v1, cluster_env);
        self._deploy_grafana(app_name, namespace, apps_v1, core_v1, cluster_env);
    }

    """Destroy all monitoring resources: Prometheus, Grafana, kube-state-metrics, node-exporter."""
    def destroy(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any
    ) -> None {
        prometheus_name = f"{app_name}-prometheus";
        grafana_name = f"{app_name}-grafana";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        cluster_role_name = f"{namespace}-{ksm_name}";
        cluster_role_binding_name = f"{namespace}-{ksm_name}";

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
                raise ;
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
                raise ;
            }
        }
        # ClusterRole and ClusterRoleBinding are cluster-scoped (no namespace param)
        rbac_v1 = client.RbacAuthorizationV1Api();
        try {
            rbac_v1.delete_cluster_role(name=cluster_role_name);
        } except ApiException as e {
            if e.status != 404 {
                raise ;
            }
        }
        try {
            rbac_v1.delete_cluster_role_binding(name=cluster_role_binding_name);
        } except ApiException as e {
            if e.status != 404 {
                raise ;
            }
        }
        # node-exporter resources (DaemonSet)
        try {
            apps_v1.delete_namespaced_daemon_set(name=ne_name, namespace=namespace);
        } except ApiException as e {
            if e.status != 404 {
                raise ;
            }
        }
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{ne_name}-service",
            namespace,
            'Service'
        );

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
                    raise ;
                }
            }
        }
        delete_k8s_secret(core_v1, namespace, f"{grafana_name}-secret");

        if self.logger {
            self.logger.info(f"Monitoring stack destroyed for '{app_name}'");
        }
    }
}
