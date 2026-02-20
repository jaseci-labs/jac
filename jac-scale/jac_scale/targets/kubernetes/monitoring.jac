"""Prometheus and Grafana monitoring stack deployer for Kubernetes."""
import re;
import from typing { Any }
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

    """Deploy Prometheus ConfigMap with scrape config + Deployment + ClusterIP Service."""
    def _deploy_prometheus(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        is_aws: bool
    ) -> None {
        prometheus_name = f"{app_name}-prometheus";
        # Use the service port (80 on AWS LoadBalancer, container_port on local NodePort)
        service_port = 80 if is_aws else self.k8s_config.container_port;

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

        prometheus_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{prometheus_name}-config",
                'namespace': namespace,
                'labels': {'app': prometheus_name}
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
                'labels': {'app': prometheus_name}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': prometheus_name}},
                'template': {
                    'metadata': {'labels': {'app': prometheus_name}},
                    'spec': {
                        'containers': [
                            {
                                'name': 'prometheus',
                                'image': 'prom/prometheus:latest',
                                'args': [
                                    '--config.file=/etc/prometheus/prometheus.yml',
                                    '--storage.tsdb.path=/prometheus',
                                    '--web.console.libraries=/usr/share/prometheus/console_libraries',
                                    '--web.console.templates=/usr/share/prometheus/consoles'
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
        try {
            apps_v1.read_namespaced_deployment(
                name=prometheus_name, namespace=namespace
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
                'labels': {'app': prometheus_name}
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

    """Deploy Grafana admin Secret, datasource ConfigMap, Deployment and Service.

    On AWS a dedicated LoadBalancer (NLB) is created on port 80.
    On non-AWS a NodePort is used.
    """
    def _deploy_grafana(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        is_aws: bool
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
                'labels': {'app': grafana_name}
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
                'labels': {'app': grafana_name}
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
                'labels': {'app': grafana_name}
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
        dashboard_json = (
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
            # --- Additional latency panels ---

            # 7. p95 Latency by Path which endpoints are slowest
            '{"id":7,"type":"timeseries","title":"p95 Latency by Path",'
            '"gridPos":{"x":0,"y":24,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,path))",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}' + '}]},'
            # 8. p95 Latency by Method GET vs POST etc
            '{"id":8,"type":"timeseries","title":"p95 Latency by Method",'
            '"gridPos":{"x":12,"y":24,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,method))",'
            f'"legendFormat":"{{{{method}}}}","datasource":{ds}' + '}]},'
            # 9. Average Request Duration over time
            '{"id":9,"type":"timeseries","title":"Average Request Duration",'
            '"gridPos":{"x":0,"y":32,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"rate({pfx}_http_request_duration_seconds_sum[5m]) / rate({pfx}_http_request_duration_seconds_count[5m])",'
            f'"legendFormat":"avg latency","datasource":{ds}' + '}]},'
            # 10. Average Latency per Path
            '{"id":10,"type":"timeseries","title":"Average Latency per Path",'
            '"gridPos":{"x":12,"y":32,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_request_duration_seconds_sum[5m])) by (path) / sum(rate({pfx}_http_request_duration_seconds_count[5m])) by (path)",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}' + '}]},'
            # 11. Request Duration Heatmap
            '{"id":11,"type":"heatmap","title":"Request Duration Heatmap",'
            '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
            f'"datasource":{ds},'
            '"options":{"calculate":false,"yAxis":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(increase({pfx}_http_request_duration_seconds_bucket[1m])) by (le)",'
            '"format":"heatmap",'
            f'"legendFormat":"{{{{le}}}}","datasource":{ds}' + '}]}' ']}'
        );
        grafana_dashboard_configmap = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': {
                'name': f"{grafana_name}-dashboard",
                'namespace': namespace,
                'labels': {'app': grafana_name}
            },
            'data': {'jac-scale.json': dashboard_json}
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
                'labels': {'app': grafana_name}
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
        if is_aws {
            grafana_service = {
                'apiVersion': 'v1',
                'kind': 'Service',
                'metadata': {
                    'name': f"{grafana_name}-service",
                    'namespace': namespace,
                    'labels': {'app': grafana_name},
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
                    'labels': {'app': grafana_name}
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
            if is_aws {
                self.logger.info(f"Grafana deployed for '{app_name}'");
            } else {
                self.logger.info(
                    f"Grafana deployed for '{app_name}' accessible at localhost:{self.k8s_config.grafana_node_port}"
                );
            }
        }
    }

    """Deploy the full monitoring stack (Prometheus and/or Grafana) for an app namespace."""
    def deploy(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any,
        is_aws: bool
    ) -> None {
        if not self.k8s_config.monitoring_enabled {
            return;
        }

        self._deploy_prometheus(app_name, namespace, apps_v1, core_v1, is_aws);
        self._deploy_grafana(app_name, namespace, apps_v1, core_v1, is_aws);
    }

    """Destroy all Prometheus and Grafana resources for an app namespace."""
    def destroy(
        self: MonitoringDeployer,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any
    ) -> None {
        prometheus_name = f"{app_name}-prometheus";
        grafana_name = f"{app_name}-grafana";

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
