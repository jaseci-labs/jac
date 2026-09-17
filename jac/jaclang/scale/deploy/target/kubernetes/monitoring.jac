import re;
import hashlib;
import from jaclang.scale._optdeps.kubernetes { client, ApiException }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    apply_k8s_resource,
    delete_if_exists,
    delete_k8s_secret
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }

obj MonitoringDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    def ensure_service(core_v1: any, name: str, namespace: str, body: dict[str, any]) {
        apply_k8s_resource(core_v1, "Service", name, body, namespace=namespace, replace=False);
    }

    def _deploy_prometheus(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        provider: ClusterProvider,
        scrape_target_service: str = ""
    ) {
        prometheus_name = f"{app_name}-prometheus";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        service_port = provider.prometheus_scrape_port(self.k8s_config.container_port);
        scrape_target = scrape_target_service or f"{app_name}-service";

        scrape_config = (
            "global:\n"
            "  scrape_interval: 15s\n"
            "  evaluation_interval: 15s\n"
            "scrape_configs:\n"
            f"  - job_name: '{app_name}'\n"
            "    static_configs:\n"
            f"      - targets: ['{scrape_target}:{service_port}']\n"
            "    metrics_path: '/metrics'\n"
            "    basic_auth:\n"
            f"      username: '{self.k8s_config.admin_username}'\n"
            "      password_file: /etc/prometheus/scrape-secret/password\n"
        );
        if self.k8s_config.k8s_metrics_enabled {
            scrape_config = scrape_config
                + (
                    f"  - job_name: 'kube-state-metrics'\n"
                    "    static_configs:\n"
                    f"      - targets: ['{ksm_name}-service:8080']\n"
                    "    metrics_path: '/metrics'\n"
                    f"  - job_name: 'node-exporter'\n"
                    "    static_configs:\n"
                    f"      - targets: ['{ne_name}-service:9100']\n"
                    "    metrics_path: '/metrics'\n"
                );

            scrape_config = scrape_config
                + (
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
        apply_k8s_resource(core_v1, "ConfigMap", f"{prometheus_name}-config", prometheus_configmap, namespace=namespace);

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
        apply_k8s_resource(core_v1, "Secret", scrape_secret_name, scrape_secret, namespace=namespace);

        prometheus_sa_name = f"{prometheus_name}-sa";

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
        apply_k8s_resource(core_v1, "ServiceAccount", prometheus_sa_name, prometheus_sa, namespace=namespace, replace=False);

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
        apply_k8s_resource(prometheus_rbac_v1, "ClusterRole", prometheus_cluster_role_name, prometheus_cluster_role);
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
        apply_k8s_resource(prometheus_rbac_v1, "ClusterRoleBinding", prometheus_cluster_role_name, prometheus_crb);

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
                                'image': 'prom/prometheus:v3.14.0',
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
        self.ensure_service(
            core_v1, f"{prometheus_name}-service", namespace, prometheus_service
        );

        if self.logger {
            self.logger.info(f"Prometheus deployed for '{app_name}'");
        }
    }

    def _deploy_kube_state_metrics(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) {
        ksm_name = f"{app_name}-kube-state-metrics";
        ksm_sa_name = f"{ksm_name}-sa";

        cluster_role_name = f"{namespace}-{ksm_name}";
        cluster_role_binding_name = f"{namespace}-{ksm_name}";
        rbac_v1 = client.RbacAuthorizationV1Api();

        sa_body = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': ksm_sa_name,
                'namespace': namespace,
                'labels': {'app': ksm_name, 'managed': 'jac-scale'}
            }
        };
        apply_k8s_resource(core_v1, "ServiceAccount", ksm_sa_name, sa_body, namespace=namespace, replace=False);

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
        apply_k8s_resource(rbac_v1, "ClusterRole", cluster_role_name, cluster_role_body, replace=False);

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
        apply_k8s_resource(rbac_v1, "ClusterRoleBinding", cluster_role_binding_name, crb_body, replace=False);

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
        apply_k8s_resource(apps_v1, "Deployment", ksm_name, ksm_deployment, namespace=namespace, replace=False);

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
        self.ensure_service(core_v1, f"{ksm_name}-service", namespace, ksm_service);

        if self.logger {
            self.logger.info(f"kube-state-metrics deployed for '{app_name}'");
        }
    }

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
        apply_k8s_resource(apps_v1, "DaemonSet", ne_name, ne_daemonset, namespace=namespace, replace=False);

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
        self.ensure_service(core_v1, f"{ne_name}-service", namespace, ne_service);

        if self.logger {
            self.logger.info(f"node-exporter deployed for '{app_name}'");
        }
    }

    def _deploy_grafana(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        grafana_name = f"{app_name}-grafana";
        prometheus_name = f"{app_name}-prometheus";
        grafana_secret_name = f"{grafana_name}-secret";

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
        apply_k8s_resource(core_v1, "Secret", grafana_secret_name, grafana_secret, namespace=namespace, replace=False);

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
            datasource_yaml = datasource_yaml
                + (
                    "  - name: Loki\n"
                    "    uid: loki\n"
                    "    type: loki\n"
                    f"    url: {loki_url}\n"
                    "    access: proxy\n"
                    "    editable: true\n"
                );
        }

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
                tempo_ds = tempo_ds
                    + (
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
        apply_k8s_resource(core_v1, "ConfigMap", f"{grafana_name}-datasources", grafana_ds_configmap, namespace=namespace);

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
        apply_k8s_resource(core_v1, "ConfigMap", f"{grafana_name}-dashboard-provider", grafana_provider_configmap, namespace=namespace);

        pfx = re.sub(r'[^a-zA-Z0-9]', '_', namespace);
        pfx = re.sub(r'_+', '_', pfx).strip('_');
        if pfx and pfx[0].isdigit() {
            pfx = f"_{pfx}";
        }
        ds = '{"type":"prometheus","uid":"prometheus"}';

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
            f'"datasource":{ds}'
            + '}]},'
            '{"id":2,"type":"timeseries","title":"Error Rate (5xx req/s)",'
            '"gridPos":{"x":12,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total'
            + '{status_code=~\\"5..\\"}[1m]))",'
            '"legendFormat":"5xx errors",'
            f'"datasource":{ds}'
            + '}]},'
            '{"id":3,"type":"timeseries","title":"Request Latency p50/p95/p99",'
            '"gridPos":{"x":0,"y":8,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            f'"datasource":{ds},'
            '"targets":['
            f'{{"refId":"A","expr":"histogram_quantile(0.50,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
            f'"legendFormat":"p50","datasource":{ds}'
            + '},'
            f'{{"refId":"B","expr":"histogram_quantile(0.95,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
            f'"legendFormat":"p95","datasource":{ds}'
            + '},'
            f'{{"refId":"C","expr":"histogram_quantile(0.99,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
            f'"legendFormat":"p99","datasource":{ds}'
            + '}]},'
            '{"id":4,"type":"stat","title":"Active Requests",'
            '"gridPos":{"x":12,"y":8,"w":6,"h":8},'
            f'"datasource":{ds},'
            f'"targets":[{{"refId":"A","expr":"{pfx}_http_requests_in_progress",'
            f'"legendFormat":"active","datasource":{ds}'
            + '}]},'
            '{"id":5,"type":"timeseries","title":"Requests by Status Code",'
            '"gridPos":{"x":0,"y":16,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (status_code)",'
            f'"legendFormat":"{{{{status_code}}}}","datasource":{ds}'
            + '}]},'
            '{"id":6,"type":"timeseries","title":"Requests by Path",'
            '"gridPos":{"x":12,"y":16,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"reqps"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (path)",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}'
            + '}]},'
            '{"id":7,"type":"timeseries","title":"p95 Latency by Path",'
            '"gridPos":{"x":0,"y":24,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,path))",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}'
            + '}]},'
            '{"id":8,"type":"timeseries","title":"p95 Latency by Method",'
            '"gridPos":{"x":12,"y":24,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,method))",'
            f'"legendFormat":"{{{{method}}}}","datasource":{ds}'
            + '}]},'
            '{"id":9,"type":"timeseries","title":"Average Request Duration",'
            '"gridPos":{"x":0,"y":32,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"rate({pfx}_http_request_duration_seconds_sum[5m]) / rate({pfx}_http_request_duration_seconds_count[5m])",'
            f'"legendFormat":"avg latency","datasource":{ds}'
            + '}]},'
            '{"id":10,"type":"timeseries","title":"Average Latency per Path",'
            '"gridPos":{"x":12,"y":32,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"fieldConfig":{"defaults":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(rate({pfx}_http_request_duration_seconds_sum[5m])) by (path) / sum(rate({pfx}_http_request_duration_seconds_count[5m])) by (path)",'
            f'"legendFormat":"{{{{path}}}}","datasource":{ds}'
            + '}]},'
            '{"id":11,"type":"heatmap","title":"Request Duration Heatmap",'
            '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
            f'"datasource":{ds},'
            '"options":{"calculate":false,"yAxis":{"unit":"s"}},'
            '"targets":[{"refId":"A",'
            f'"expr":"sum(increase({pfx}_http_request_duration_seconds_bucket[1m])) by (le)",'
            '"format":"heatmap",'
            f'"legendFormat":"{{{{le}}}}","datasource":{ds}'
            + '}]}' ']}'
        );

        k8s_dashboard_json = (
            '{"title":"Kubernetes Cluster Metrics","uid":"k8s-cluster",'
            '"schemaVersion":36,"refresh":"30s","time":{"from":"now-1h","to":"now"},'
            '"panels":['
            '{"id":1,"type":"timeseries","title":"Node CPU Usage (%)",'
            '"gridPos":{"x":0,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - avg(rate(node_cpu_seconds_total'
            + '{mode=\\"idle\\"}[5m])) by (instance)) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
            + '}]},'
            '{"id":2,"type":"timeseries","title":"Node Memory Usage (%)",'
            '"gridPos":{"x":12,"y":0,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
            + '}]},'
            '{"id":3,"type":"stat","title":"Running Pods",'
            '"gridPos":{"x":0,"y":8,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_status_phase'
            + '{phase=\\"Running\\"} == 1) or vector(0)",'
            f'"legendFormat":"Running","datasource":{ds}'
            + '}]},'
            '{"id":4,"type":"stat","title":"Pending Pods",'
            '"gridPos":{"x":6,"y":8,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_status_phase'
            + '{phase=\\"Pending\\"} == 1) or vector(0)",'
            f'"legendFormat":"Pending","datasource":{ds}'
            + '}]},'
            '{"id":5,"type":"stat","title":"Failed Pods",'
            '"gridPos":{"x":12,"y":8,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_status_phase'
            + '{phase=\\"Failed\\"} == 1) or vector(0)",'
            f'"legendFormat":"Failed","datasource":{ds}'
            + '}]},'
            '{"id":6,"type":"timeseries","title":"Deployment Available Replicas",'
            '"gridPos":{"x":0,"y":12,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"kube_deployment_status_replicas_available",'
            f'"legendFormat":"{{{{deployment}}}}","datasource":{ds}'
            + '}]},'
            '{"id":7,"type":"timeseries","title":"Pod Container Restarts (last 1h)",'
            '"gridPos":{"x":12,"y":12,"w":12,"h":8},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod) > 0",'
            f'"legendFormat":"{{{{pod}}}}","datasource":{ds}'
            + '}]},'
            '{"id":8,"type":"timeseries","title":"Node Disk Read/Write (Bps)",'
            '"gridPos":{"x":0,"y":20,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"Bps"}},'
            f'"datasource":{ds},'
            '"targets":['
            '{"refId":"A",'
            '"expr":"sum(rate(node_disk_read_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} read","datasource":{ds}'
            + '},'
            '{"refId":"B",'
            '"expr":"sum(rate(node_disk_written_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} write","datasource":{ds}'
            + '}]},'
            '{"id":9,"type":"timeseries","title":"Node Network Receive/Transmit (Bps)",'
            '"gridPos":{"x":12,"y":20,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"Bps"}},'
            f'"datasource":{ds},'
            '"targets":['
            '{"refId":"A",'
            '"expr":"sum(rate(node_network_receive_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} rx","datasource":{ds}'
            + '},'
            '{"refId":"B",'
            '"expr":"sum(rate(node_network_transmit_bytes_total[5m])) by (instance)",'
            f'"legendFormat":"{{{{instance}}}} tx","datasource":{ds}'
            + '}]},'
            '{"id":10,"type":"timeseries","title":"Pod CPU Requests (cores)",'
            '"gridPos":{"x":0,"y":28,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests'
            + '{resource=\\"cpu\\"}) by (pod)",'
            f'"legendFormat":"{{{{pod}}}}","datasource":{ds}'
            + '}]},'
            '{"id":11,"type":"timeseries","title":"Pod Memory Requests (bytes)",'
            '"gridPos":{"x":12,"y":28,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"bytes"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests'
            + '{resource=\\"memory\\"}) by (pod)",'
            f'"legendFormat":"{{{{pod}}}}","datasource":{ds}'
            + '}]},'
            '{"id":12,"type":"stat","title":"Total Nodes",'
            '"gridPos":{"x":0,"y":36,"w":6,"h":4},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_node_info) or vector(0)",'
            f'"legendFormat":"nodes","datasource":{ds}'
            + '}]},'
            '{"id":13,"type":"stat","title":"Ready Nodes",'
            '"gridPos":{"x":6,"y":36,"w":6,"h":4},'
            '"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},'
            '"thresholds":{"steps":[{"color":"red","value":0},{"color":"green","value":1}]}}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_node_status_condition'
            + '{condition=\\"Ready\\",status=\\"true\\"} == 1) or vector(0)",'
            f'"legendFormat":"ready","datasource":{ds}'
            + '}]},'
            '{"id":14,"type":"stat","title":"Not-Ready Nodes",'
            '"gridPos":{"x":12,"y":36,"w":6,"h":4},'
            '"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},'
            '"thresholds":{"steps":[{"color":"green","value":0},{"color":"red","value":1}]}}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_node_status_condition'
            + '{condition=\\"Ready\\",status=\\"false\\"} == 1) or vector(0)",'
            f'"legendFormat":"not-ready","datasource":{ds}'
            + '}]},'
            '{"id":15,"type":"timeseries","title":"Pods per Node",'
            '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"count(kube_pod_info'
            + '{node!=\\"\\"}) by (node)",'
            f'"legendFormat":"{{{{node}}}}","datasource":{ds}'
            + '}]},'
            '{"id":16,"type":"timeseries","title":"Node CPU Usage (%) per Node",'
            '"gridPos":{"x":0,"y":48,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - avg(rate(node_cpu_seconds_total'
            + '{mode=\\"idle\\"}[5m])) by (instance)) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
            + '}]},'
            '{"id":17,"type":"timeseries","title":"Node Memory Usage (%) per Node",'
            '"gridPos":{"x":12,"y":48,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",'
            f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
            + '}]},'
            '{"id":18,"type":"timeseries","title":"CPU Requests per Node (cores)",'
            '"gridPos":{"x":0,"y":56,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"short"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests'
            + '{resource=\\"cpu\\"}) by (node)",'
            f'"legendFormat":"{{{{node}}}}","datasource":{ds}'
            + '}]},'
            '{"id":19,"type":"timeseries","title":"Memory Requests per Node (bytes)",'
            '"gridPos":{"x":12,"y":56,"w":12,"h":8},'
            '"fieldConfig":{"defaults":{"unit":"bytes"}},'
            f'"datasource":{ds},'
            '"targets":[{"refId":"A",'
            '"expr":"sum(kube_pod_container_resource_requests'
            + '{resource=\\"memory\\"}) by (node)",'
            f'"legendFormat":"{{{{node}}}}","datasource":{ds}'
            + '}]}' ']}'
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
            f'"legendFormat":"{{{{namespace}}}}/{{{{pod}}}}","datasource":{lds}'
            + '}]},'
            '{"id":2,"type":"logs","title":"All Pod Logs",'
            '"gridPos":{"x":0,"y":6,"w":24,"h":20},'
            f'"datasource":{lds},'
            '"options":{"dedupStrategy":"none","showLabels":true,'
            '"showCommonLabels":false,"wrapLogMessage":true,"sortOrder":"Descending"},'
            '"targets":[{"refId":"A",'
            '"expr":"{namespace=~\\".+\\"}",'
            f'"datasource":{lds}'
            + '}]}]}'
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
        apply_k8s_resource(core_v1, "ConfigMap", f"{grafana_name}-dashboard", grafana_dashboard_configmap, namespace=namespace);

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
        apply_k8s_resource(core_v1, "ServiceAccount", grafana_sa_name, grafana_sa, namespace=namespace, replace=False);

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
                                'image': 'grafana/grafana:13.2.0',
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

        self.ensure_service(
            core_v1, f"{grafana_name}-service", namespace, grafana_service
        );

        if self.logger {
            self.logger.info(
                f"Grafana deployed for '{app_name}' (ClusterIP service "
                f"{grafana_name}-service:3000; served at /grafana when the app "
                "ingress is deployed, otherwise reach it via kubectl port-forward)"
            );
        }
    }

    def _deploy_tempo(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
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
        apply_k8s_resource(core_v1, "ConfigMap", f"{tempo_name}-config", tempo_configmap, namespace=namespace);

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
        apply_k8s_resource(core_v1, "ServiceAccount", tempo_sa_name, tempo_sa, namespace=namespace, replace=False);

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
        self.ensure_service(core_v1, f"{tempo_name}-service", namespace, tempo_service);

        if self.logger {
            self.logger.info(f"Tempo deployed for '{app_name}'");
        }
    }

    def _deploy_loki(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
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
        apply_k8s_resource(core_v1, "ConfigMap", f"{loki_name}-config", loki_configmap, namespace=namespace);

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
        apply_k8s_resource(core_v1, "ServiceAccount", loki_sa_name, loki_sa, namespace=namespace, replace=False);

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
        self.ensure_service(core_v1, f"{loki_name}-service", namespace, loki_service);

        if self.logger {
            self.logger.info(f"Loki deployed for '{app_name}'");
        }
    }

    def _deploy_alloy(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        loki_name = f"{app_name}-loki";
        alloy_name = f"{app_name}-alloy";
        alloy_sa_name = f"{alloy_name}-sa";
        cluster_role_name = f"{namespace}-{alloy_name}";
        cluster_role_binding_name = f"{namespace}-{alloy_name}";
        rbac_v1 = client.RbacAuthorizationV1Api();
        loki_push_url = f"http://{loki_name}-service:3100/loki/api/v1/push";
        tempo_name = f"{app_name}-tempo";
        tempo_otlp_endpoint = f"{tempo_name}-service:4317";

        alloy_header = (
            "logging {\n" "  level  = \"info\"\n" "  format = \"logfmt\"\n" "}\n" "\n"
        );

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

        if not self.k8s_config.loki_enabled {
            alloy_logs_lane = "";
        }

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
        apply_k8s_resource(core_v1, "ConfigMap", f"{alloy_name}-config", alloy_configmap, namespace=namespace);

        alloy_sa = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': alloy_sa_name,
                'namespace': namespace,
                'labels': {'app': alloy_name, 'managed': 'jac-scale'}
            }
        };
        apply_k8s_resource(core_v1, "ServiceAccount", alloy_sa_name, alloy_sa, namespace=namespace, replace=False);

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
        apply_k8s_resource(rbac_v1, "ClusterRole", cluster_role_name, cluster_role_body, replace=False);

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
        apply_k8s_resource(rbac_v1, "ClusterRoleBinding", cluster_role_binding_name, crb_body, replace=False);

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
                                    'runAsUser': 0,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': [
                                    'run',
                                    '--server.http.listen-addr=0.0.0.0:12345',
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
        apply_k8s_resource(apps_v1, "DaemonSet", alloy_name, alloy_daemonset, namespace=namespace, replace=False);

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
            self.ensure_service(
                core_v1, f"{alloy_name}-service", namespace, alloy_service
            );
        }

        if self.logger {
            self.logger.info(f"Alloy deployed for '{app_name}'");
        }
    }

    def deploy(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        provider: ClusterProvider,
        scrape_target_service: str = ""
    ) {
        if self.k8s_config.monitoring_enabled {
            if self.k8s_config.k8s_metrics_enabled {
                self._deploy_kube_state_metrics(app_name, namespace, apps_v1, core_v1);
                self._deploy_node_exporter(app_name, namespace, apps_v1, core_v1);
            }
            self._deploy_prometheus(
                app_name, namespace, apps_v1, core_v1, provider, scrape_target_service
            );
        }
        if self.k8s_config.tracing_enabled {
            self._deploy_tempo(app_name, namespace, apps_v1, core_v1);
        }
        if self.k8s_config.loki_enabled {
            self._deploy_loki(app_name, namespace, apps_v1, core_v1);
        }

        if self.k8s_config.loki_enabled or self.k8s_config.tracing_enabled {
            self._deploy_alloy(app_name, namespace, apps_v1, core_v1);
        }
        if self.k8s_config.monitoring_enabled
            or self.k8s_config.loki_enabled
            or self.k8s_config.tracing_enabled {
            self._deploy_grafana(app_name, namespace, apps_v1, core_v1);
        }
    }

    def destroy(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        prometheus_name = f"{app_name}-prometheus";
        grafana_name = f"{app_name}-grafana";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        loki_name = f"{app_name}-loki";
        alloy_name = f"{app_name}-alloy";
        cluster_role_name = f"{namespace}-{ksm_name}";
        cluster_role_binding_name = f"{namespace}-{ksm_name}";
        prometheus_cluster_role_name = f"{namespace}-{prometheus_name}";

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
        delete_if_exists(core_v1.delete_namespaced_config_map, f"{prometheus_name}-config", namespace, "ConfigMap");
        delete_k8s_secret(core_v1, namespace, f"{prometheus_name}-scrape-secret");
        delete_if_exists(core_v1.delete_namespaced_service_account, f"{prometheus_name}-sa", namespace, "ServiceAccount");

        delete_if_exists(
            apps_v1.delete_namespaced_deployment, ksm_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{ksm_name}-service",
            namespace,
            'Service'
        );
        delete_if_exists(core_v1.delete_namespaced_service_account, f"{ksm_name}-sa", namespace, "ServiceAccount");

        rbac_v1 = client.RbacAuthorizationV1Api();
        delete_if_exists(rbac_v1.delete_cluster_role, cluster_role_name, "", "ClusterRole");
        delete_if_exists(rbac_v1.delete_cluster_role_binding, cluster_role_binding_name, "", "ClusterRoleBinding");

        delete_if_exists(rbac_v1.delete_cluster_role, prometheus_cluster_role_name, "", "ClusterRole");
        delete_if_exists(rbac_v1.delete_cluster_role_binding, prometheus_cluster_role_name, "", "ClusterRoleBinding");

        delete_if_exists(apps_v1.delete_namespaced_daemon_set, ne_name, namespace, "DaemonSet");
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{ne_name}-service",
            namespace,
            'Service'
        );

        delete_if_exists(
            apps_v1.delete_namespaced_deployment, loki_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{loki_name}-service",
            namespace,
            'Service'
        );
        delete_if_exists(core_v1.delete_namespaced_config_map, f"{loki_name}-config", namespace, "ConfigMap");
        delete_if_exists(core_v1.delete_namespaced_service_account, f"{loki_name}-sa", namespace, "ServiceAccount");

        delete_if_exists(apps_v1.delete_namespaced_daemon_set, alloy_name, namespace, "DaemonSet");
        delete_if_exists(core_v1.delete_namespaced_config_map, f"{alloy_name}-config", namespace, "ConfigMap");
        delete_if_exists(core_v1.delete_namespaced_service_account, f"{alloy_name}-sa", namespace, "ServiceAccount");

        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{alloy_name}-service",
            namespace,
            'Service'
        );
        alloy_cr_name = f"{namespace}-{alloy_name}";
        delete_if_exists(rbac_v1.delete_cluster_role, alloy_cr_name, "", "ClusterRole");
        delete_if_exists(rbac_v1.delete_cluster_role_binding, alloy_cr_name, "", "ClusterRoleBinding");

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
        delete_if_exists(core_v1.delete_namespaced_config_map, f"{tempo_name}-config", namespace, "ConfigMap");
        delete_if_exists(core_v1.delete_namespaced_service_account, f"{tempo_name}-sa", namespace, "ServiceAccount");

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
            delete_if_exists(core_v1.delete_namespaced_config_map, cm_name, namespace, "ConfigMap");
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
