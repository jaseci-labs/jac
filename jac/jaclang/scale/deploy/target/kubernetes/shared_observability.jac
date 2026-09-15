import re;
import hashlib;
import from jaclang.scale._optdeps.kubernetes { client, ApiException }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig,
    k8s_safe_slug
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    privileged_pss_labels
}

glob PSS_ENFORCE: str = 'pod-security.kubernetes.io/enforce',
     LANE_WRITE_ATTEMPTS: int = 5,
     SHARED_OBS_NAMESPACE: str = 'jac-observability',
     NODE_EXPORTER_NAME: str = 'jac-node-exporter',
     KSM_NAME: str = 'jac-kube-state-metrics',
     PROMETHEUS_NAME: str = 'jac-prometheus',
     ALLOY_NAME: str = 'jac-alloy',
     PROMETHEUS_LANES_CM: str = 'jac-prometheus-lanes',
     ALLOY_LANES_CM: str = 'jac-alloy-lanes',
     SCRAPE_SECRET_NAME: str = 'jac-prometheus-scrape',
     SHARED_LABELS: dict[str, str] = {
         'managed': 'jac-scale',
         'tier': 'shared-observability'
     },
     PROM_RELOADER_SCRIPT: str = "LAST=\"\"\nwhile true; do\n  CUR=$(md5sum /etc/prometheus/prometheus.yml 2>/dev/null)\n  if [ \"$CUR\" != \"$LAST\" ]; then\n    if [ -n \"$LAST\" ]; then\n      wget -q -O- --post-data='' http://127.0.0.1:9090/-/reload >/dev/null 2>&1 || true\n    fi\n    LAST=\"$CUR\"\n  fi\n  sleep 10\ndone\n",
     ALLOY_RELOADER_SCRIPT: str = "LAST=\"\"\nwhile true; do\n  CUR=$(md5sum /etc/alloy/config.alloy 2>/dev/null)\n  if [ \"$CUR\" != \"$LAST\" ]; then\n    if [ -n \"$LAST\" ]; then\n      wget -q -O- --post-data='' http://127.0.0.1:12345/-/reload >/dev/null 2>&1 || true\n    fi\n    LAST=\"$CUR\"\n  fi\n  sleep 10\ndone\n";


def lane_key(app_name: str, app_namespace: str) -> str {
    return f"{k8s_safe_slug(app_namespace)}__{k8s_safe_slug(app_name)}";
}


def river_ident(app_name: str, app_namespace: str) -> str {
    raw = lane_key(app_name, app_namespace);
    ident = re.sub(r'[^a-zA-Z0-9_]', '_', raw);
    return re.sub(r'_+', '_', ident).strip('_') or 'app';
}


obj SharedObservability {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None,
        rbac_api: any = None;

    def _rbac -> any {
        return self.rbac_api
            if self.rbac_api is not None
            else client.RbacAuthorizationV1Api();
    }

    def namespace -> str {
        configured = str(getattr(self.k8s_config, 'observability_namespace', '') or '');
        return configured or SHARED_OBS_NAMESPACE;
    }

    def cluster_scoped_name(component: str) -> str {
        return f"{self.namespace()}-{component}";
    }

    def _log(message: str) {
        if self.logger {
            self.logger.info(message);
        }
    }

    def _ensure_namespace(core_v1: any) {
        ns = self.namespace();
        body = {
            'apiVersion': 'v1',
            'kind': 'Namespace',
            'metadata': {
                'name': ns,
                'labels': dict(SHARED_LABELS) | {PSS_ENFORCE: 'privileged'}
            }
        };
        try {
            found = core_v1.read_namespace(name=ns);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
            core_v1.create_namespace(body=body);
            self._log(f"Created shared observability namespace '{ns}'");
            return;
        }

        meta = found?.metadata;
        labels = dict(getattr(meta, 'labels', {}) or {}) if meta else {};
        patch_labels = privileged_pss_labels(labels);
        if patch_labels is None {
            self._log(
                f"namespace '{ns}' enforces a pod-security policy set outside "
                f"jac-scale; the node-level DaemonSets may be rejected"
            );
            return;
        }
        if not patch_labels {
            return;
        }
        try {
            core_v1.patch_namespace(
                name=ns, body={'metadata': {'labels': patch_labels}}
            );
            self._log(f"Labeled '{ns}' pod-security enforce=privileged");
        } except ApiException {
            self._log(f"Could not label '{ns}' privileged");
        }
    }

    def _ensure_service_account(core_v1: any, name: str) {
        ns = self.namespace();
        body = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {'name': name, 'namespace': ns, 'labels': dict(SHARED_LABELS)}
        };
        try {
            core_v1.read_namespaced_service_account(name=name, namespace=ns);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(namespace=ns, body=body);
            } else {
                raise;
            }
        }
    }

    def _ensure_cluster_role(name: str, rules: list[dict[str, any]], sa_name: str) {
        rbac_v1 = self._rbac();
        role = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRole',
            'metadata': {'name': name, 'labels': dict(SHARED_LABELS)},
            'rules': rules
        };
        try {
            rbac_v1.read_cluster_role(name=name);
            rbac_v1.replace_cluster_role(name=name, body=role);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role(body=role);
            } else {
                raise;
            }
        }
        binding = {
            'apiVersion': 'rbac.authorization.k8s.io/v1',
            'kind': 'ClusterRoleBinding',
            'metadata': {'name': name, 'labels': dict(SHARED_LABELS)},
            'roleRef': {
                'apiGroup': 'rbac.authorization.k8s.io',
                'kind': 'ClusterRole',
                'name': name
            },
            'subjects': [
                {
                    'kind': 'ServiceAccount',
                    'name': sa_name,
                    'namespace': self.namespace()
                }
            ]
        };
        try {
            rbac_v1.read_cluster_role_binding(name=name);
            rbac_v1.replace_cluster_role_binding(name=name, body=binding);
        } except ApiException as e {
            if e.status == 404 {
                rbac_v1.create_cluster_role_binding(body=binding);
            } else {
                raise;
            }
        }
    }

    def _ensure_service(
        core_v1: any, name: str, selector: dict[str, str], ports: list[dict[str, any]]
    ) {
        ns = self.namespace();
        body = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {'name': name, 'namespace': ns, 'labels': dict(SHARED_LABELS)},
            'spec': {'type': 'ClusterIP', 'selector': selector, 'ports': ports}
        };
        try {
            core_v1.read_namespaced_service(name=name, namespace=ns);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(namespace=ns, body=body);
            } else {
                raise;
            }
        }
    }

    def _ensure_daemonset(apps_v1: any, name: str, body: dict[str, any]) {
        ns = self.namespace();
        try {
            apps_v1.patch_namespaced_daemon_set(name=name, namespace=ns, body=body);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
            apps_v1.create_namespaced_daemon_set(namespace=ns, body=body);
            self._log(f"Created shared DaemonSet '{name}' in '{ns}'");
        }
    }

    def _ensure_deployment(apps_v1: any, name: str, body: dict[str, any]) {
        ns = self.namespace();
        try {
            apps_v1.patch_namespaced_deployment(name=name, namespace=ns, body=body);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
            apps_v1.create_namespaced_deployment(namespace=ns, body=body);
            self._log(f"Created shared Deployment '{name}' in '{ns}'");
        }
    }

    def _read_lanes(core_v1: any, cm_name: str) -> dict[str, str] {
        (data, rv) = self._read_lanes_versioned(core_v1, cm_name);
        return data;
    }

    def _read_lanes_versioned(
        core_v1: any, cm_name: str
    ) -> tuple[dict[str, str], str] {
        ns = self.namespace();
        try {
            existing = core_v1.read_namespaced_config_map(name=cm_name, namespace=ns);
            meta = existing?.metadata;
            rv = str(getattr(meta, 'resource_version', '') or '') if meta else '';
            return (dict(getattr(existing, 'data', {}) or {}), rv);
        } except ApiException as e {
            if e.status == 404 {
                return ({}, '');
            }
            raise;
        }
    }

    def _put_lane(
        core_v1: any, cm_name: str, key: str, value: (str | None)
    ) -> dict[str, str] {
        attempt = 0;
        while attempt < LANE_WRITE_ATTEMPTS {
            attempt += 1;
            (lanes, rv) = self._read_lanes_versioned(core_v1, cm_name);
            if value is None {
                if key not in lanes {
                    return lanes;
                }
                lanes.pop(key, None);
            } else {
                if lanes.get(key) == value {
                    return lanes;
                }
                lanes[key] = value;
            }
            try {
                self._write_lanes(core_v1, cm_name, lanes, rv);
                return lanes;
            } except ApiException as e {
                if e.status != 409 or attempt >= LANE_WRITE_ATTEMPTS {
                    raise;
                }
            }
        }
        return self._read_lanes(core_v1, cm_name);
    }

    def _write_lanes(
        core_v1: any, cm_name: str, data: dict[str, str], resource_version: str = ''
    ) {
        ns = self.namespace();
        meta: dict[str, any] = {
            'name': cm_name,
            'namespace': ns,
            'labels': dict(SHARED_LABELS)
        };
        if resource_version {
            meta['resourceVersion'] = resource_version;
        }
        body = {
            'apiVersion': 'v1',
            'kind': 'ConfigMap',
            'metadata': meta,
            'data': data
        };
        if not resource_version {
            core_v1.create_namespaced_config_map(namespace=ns, body=body);
            return;
        }
        core_v1.replace_namespaced_config_map(name=cm_name, namespace=ns, body=body);
    }

    def _node_exporter_daemonset -> dict[str, any] {
        labels = dict(SHARED_LABELS) | {'app': NODE_EXPORTER_NAME};
        return {
            'apiVersion': 'apps/v1',
            'kind': 'DaemonSet',
            'metadata': {
                'name': NODE_EXPORTER_NAME,
                'namespace': self.namespace(),
                'labels': labels
            },
            'spec': {
                'selector': {'matchLabels': {'app': NODE_EXPORTER_NAME}},
                'template': {
                    'metadata': {'labels': labels},
                    'spec': {
                        'automountServiceAccountToken': False,
                        'hostPID': False,
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
                                'resources': {
                                    'requests': {'cpu': '10m', 'memory': '24Mi'},
                                    'limits': {'memory': '64Mi'}
                                },
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
    }

    def _ksm_deployment -> dict[str, any] {
        labels = dict(SHARED_LABELS) | {'app': KSM_NAME};
        return {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': KSM_NAME,
                'namespace': self.namespace(),
                'labels': labels
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': KSM_NAME}},
                'template': {
                    'metadata': {'labels': labels},
                    'spec': {
                        'serviceAccountName': f"{KSM_NAME}-sa",
                        'securityContext': {
                            'runAsNonRoot': True,
                            'runAsUser': 65534,
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'kube-state-metrics',
                                'image': 'registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0',
                                'securityContext': {
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'resources': {
                                    'requests': {'cpu': '20m', 'memory': '128Mi'},
                                    'limits': {'memory': '512Mi'}
                                },
                                'ports': [
                                    {'containerPort': 8080, 'name': 'http-metrics'},
                                    {'containerPort': 8081, 'name': 'telemetry'}
                                ],
                                'livenessProbe': {
                                    'httpGet': {'path': '/healthz', 'port': 8080},
                                    'initialDelaySeconds': 5
                                },
                                'readinessProbe': {
                                    'httpGet': {'path': '/', 'port': 8081},
                                    'initialDelaySeconds': 5
                                }
                            }
                        ]
                    }
                }
            }
        };
    }

    def _prometheus_deployment(config_hash: str) -> dict[str, any] {
        labels = dict(SHARED_LABELS) | {'app': PROMETHEUS_NAME};
        return {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': PROMETHEUS_NAME,
                'namespace': self.namespace(),
                'labels': labels
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': PROMETHEUS_NAME}},
                'template': {
                    'metadata': {
                        'labels': labels,
                        'annotations': {'checksum/base-config': config_hash}
                    },
                    'spec': {
                        'automountServiceAccountToken': True,
                        'serviceAccountName': f"{PROMETHEUS_NAME}-sa",
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'prometheus',
                                'image': 'prom/prometheus:v3.6.0',
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
                                    '--storage.tsdb.retention.time=15d',
                                    '--web.console.libraries=/usr/share/prometheus/console_libraries',
                                    '--web.console.templates=/usr/share/prometheus/consoles',
                                    '--web.enable-lifecycle'
                                ],
                                'resources': {
                                    'requests': {'cpu': '100m', 'memory': '512Mi'},
                                    'limits': {'memory': '2Gi'}
                                },
                                'ports': [{'containerPort': 9090}],
                                'volumeMounts': [
                                    {
                                        'name': 'prometheus-config-vol',
                                        'mountPath': '/etc/prometheus'
                                    },
                                    {
                                        'name': 'prometheus-scrape-secret',
                                        'mountPath': '/etc/prometheus-scrape',
                                        'readOnly': True
                                    },
                                    {
                                        'name': 'prometheus-data',
                                        'mountPath': '/prometheus'
                                    },
                                    {'name': 'tmp', 'mountPath': '/tmp'}
                                ]
                            },
                            {
                                'name': 'config-reloader',
                                'image': self.k8s_config.wait_image or 'busybox',
                                'securityContext': {
                                    'runAsNonRoot': True,
                                    'runAsUser': 65534,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'command': ['/bin/sh', '-c', PROM_RELOADER_SCRIPT],
                                'resources': {
                                    'requests': {'cpu': '5m', 'memory': '16Mi'},
                                    'limits': {'memory': '32Mi'}
                                },
                                'volumeMounts': [
                                    {
                                        'name': 'prometheus-config-vol',
                                        'mountPath': '/etc/prometheus',
                                        'readOnly': True
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'prometheus-config-vol',
                                'configMap': {'name': f"{PROMETHEUS_NAME}-config"}
                            },
                            {
                                'name': 'prometheus-scrape-secret',
                                'secret': {
                                    'secretName': SCRAPE_SECRET_NAME,
                                    'optional': True
                                }
                            },
                            {'name': 'prometheus-data', 'emptyDir': {}},
                            {'name': 'tmp', 'emptyDir': {}}
                        ]
                    }
                }
            }
        };
    }

    def _alloy_daemonset(config_hash: str) -> dict[str, any] {
        labels = dict(SHARED_LABELS) | {'app': ALLOY_NAME};
        return {
            'apiVersion': 'apps/v1',
            'kind': 'DaemonSet',
            'metadata': {
                'name': ALLOY_NAME,
                'namespace': self.namespace(),
                'labels': labels
            },
            'spec': {
                'selector': {'matchLabels': {'app': ALLOY_NAME}},
                'template': {
                    'metadata': {
                        'labels': labels,
                        'annotations': {'checksum/base-config': config_hash}
                    },
                    'spec': {
                        'serviceAccountName': f"{ALLOY_NAME}-sa",
                        'tolerations': [{'operator': 'Exists', 'effect': 'NoSchedule'}],
                        'securityContext': {
                            'seccompProfile': {'type': 'RuntimeDefault'}
                        },
                        'containers': [
                            {
                                'name': 'alloy',
                                'image': 'grafana/alloy:v1.11.2',
                                'securityContext': {
                                    'runAsUser': 0,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'args': [
                                    'run',
                                    '--server.http.listen-addr=0.0.0.0:12345',
                                    '--storage.path=/tmp/alloy',
                                    '/etc/alloy/config.alloy'
                                ],
                                'resources': {
                                    'requests': {'cpu': '50m', 'memory': '128Mi'},
                                    'limits': {'memory': '512Mi'}
                                },
                                'ports': [{'containerPort': 12345, 'name': 'http'}],
                                'volumeMounts': [
                                    {'name': 'alloy-config', 'mountPath': '/etc/alloy'},
                                    {
                                        'name': 'varlog',
                                        'mountPath': '/var/log/pods',
                                        'readOnly': True
                                    },
                                    {
                                        'name': 'varlibdockercontainers',
                                        'mountPath': '/var/lib/docker/containers',
                                        'readOnly': True
                                    },
                                    {'name': 'tmp', 'mountPath': '/tmp'}
                                ]
                            },
                            {
                                'name': 'config-reloader',
                                'image': self.k8s_config.wait_image or 'busybox',
                                'securityContext': {
                                    'runAsUser': 0,
                                    'readOnlyRootFilesystem': True,
                                    'allowPrivilegeEscalation': False,
                                    'capabilities': {'drop': ['ALL']}
                                },
                                'command': ['/bin/sh', '-c', ALLOY_RELOADER_SCRIPT],
                                'resources': {
                                    'requests': {'cpu': '5m', 'memory': '16Mi'},
                                    'limits': {'memory': '32Mi'}
                                },
                                'volumeMounts': [
                                    {
                                        'name': 'alloy-config',
                                        'mountPath': '/etc/alloy',
                                        'readOnly': True
                                    }
                                ]
                            }
                        ],
                        'volumes': [
                            {
                                'name': 'alloy-config',
                                'configMap': {'name': f"{ALLOY_NAME}-config"}
                            },
                            {'name': 'varlog', 'hostPath': {'path': '/var/log/pods'}},
                            {
                                'name': 'varlibdockercontainers',
                                'hostPath': {'path': '/var/lib/docker/containers'}
                            },
                            {'name': 'tmp', 'emptyDir': {}}
                        ]
                    }
                }
            }
        };
    }

    def _node_level_wanted(core_v1: any) -> bool {
        if self.k8s_config.k8s_metrics_enabled {
            return True;
        }
        try {
            core_v1.read_namespaced_service(
                name=f"{KSM_NAME}-service", namespace=self.namespace()
            );
            return True;
        } except ApiException as e {
            if e.status == 404 {
                return False;
            }
            raise;
        }
    }

    def _prometheus_base_config(node_level: bool = True) -> str {
        ns = self.namespace();
        ne_svc = f"{NODE_EXPORTER_NAME}-service";
        ksm_svc = f"{KSM_NAME}-service";
        cfg = "global:\n";
        cfg = cfg + "  scrape_interval: 15s\n";
        cfg = cfg + "  evaluation_interval: 15s\n";
        cfg = cfg + "scrape_configs:\n";
        if not node_level {
            return cfg;
        }
        cfg = cfg + "  - job_name: 'node-exporter'\n";
        cfg = cfg + "    kubernetes_sd_configs:\n";
        cfg = cfg + "      - role: endpoints\n";
        cfg = cfg + "        namespaces:\n";
        cfg = cfg + "          names: ['" + ns + "']\n";
        cfg = cfg + "    relabel_configs:\n";
        cfg = cfg + "      - source_labels: [__meta_kubernetes_service_name]\n";
        cfg = cfg + "        regex: '" + ne_svc + "'\n";
        cfg = cfg + "        action: keep\n";
        cfg = cfg + "      - source_labels: [__meta_kubernetes_pod_node_name]\n";
        cfg = cfg + "        target_label: node\n";
        cfg = cfg + "      - source_labels: [__meta_kubernetes_pod_name]\n";
        cfg = cfg + "        target_label: pod\n";
        cfg = cfg + "  - job_name: 'kube-state-metrics'\n";
        cfg = cfg + "    kubernetes_sd_configs:\n";
        cfg = cfg + "      - role: endpoints\n";
        cfg = cfg + "        namespaces:\n";
        cfg = cfg + "          names: ['" + ns + "']\n";
        cfg = cfg + "    relabel_configs:\n";
        cfg = cfg + "      - source_labels: [__meta_kubernetes_service_name]\n";
        cfg = cfg + "        regex: '" + ksm_svc + "'\n";
        cfg = cfg + "        action: keep\n";
        cfg = cfg + "      - source_labels: [__meta_kubernetes_endpoint_port_name]\n";
        cfg = cfg + "        regex: 'http-metrics'\n";
        cfg = cfg + "        action: keep\n";
        cfg = cfg + "  - job_name: 'kubernetes-cadvisor'\n";
        cfg = cfg + "    scheme: https\n";
        cfg = cfg + "    tls_config:\n";
        cfg = cfg + "      insecure_skip_verify: true\n";
        cfg = cfg + "    authorization:\n";
        cfg = cfg
            + "      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n";
        cfg = cfg + "    kubernetes_sd_configs:\n";
        cfg = cfg + "      - role: node\n";
        cfg = cfg + "    relabel_configs:\n";
        cfg = cfg + "      - action: labelmap\n";
        cfg = cfg + "        regex: __meta_kubernetes_node_label_(.+)\n";
        cfg = cfg + "      - target_label: __address__\n";
        cfg = cfg + "        replacement: kubernetes.default.svc:443\n";
        cfg = cfg + "      - source_labels: [__meta_kubernetes_node_name]\n";
        cfg = cfg + "        regex: (.+)\n";
        cfg = cfg + "        target_label: __metrics_path__\n";
        cfg = cfg + "        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor\n";
        return cfg;
    }

    def prometheus_lane(
        app_name: str, app_namespace: str, scrape_target: str, service_port: int
    ) -> str {
        key = lane_key(app_name, app_namespace);
        target = scrape_target
            + "."
            + app_namespace
            + ".svc.cluster.local:"
            + str(service_port);
        lane = "  - job_name: '" + key + "'\n";
        lane = lane + "    static_configs:\n";
        lane = lane + "      - targets: ['" + target + "']\n";
        lane = lane + "        labels:\n";
        lane = lane + "          namespace: '" + app_namespace + "'\n";
        lane = lane + "          jac_app: '" + app_name + "'\n";
        lane = lane + "    metrics_path: '/metrics'\n";
        lane = lane + "    basic_auth:\n";
        lane = lane + "      username: '" + str(self.k8s_config.admin_username) + "'\n";
        lane = lane + "      password_file: /etc/prometheus-scrape/" + key + "\n";
        return lane;
    }

    def _render_prometheus_config(
        lanes: dict[str, str], node_level: bool = True
    ) -> str {
        cfg = self._prometheus_base_config(node_level);
        for key in sorted(lanes.keys()) {
            cfg = cfg + lanes[key];
        }
        return cfg;
    }

    def _alloy_base_config -> str {
        cfg = "logging {\n";
        cfg = cfg + "  level  = \"info\"\n";
        cfg = cfg + "  format = \"logfmt\"\n";
        cfg = cfg + "}\n\n";
        cfg = cfg + "discovery.kubernetes \"pods\" {\n";
        cfg = cfg + "  role = \"pod\"\n";
        cfg = cfg + "}\n";
        return cfg;
    }

    def alloy_lane(app_name: str, app_namespace: str) -> str {
        ident = river_ident(app_name, app_namespace);
        loki_url = "http://"
            + k8s_safe_slug(app_name)
            + "-loki-service."
            + app_namespace
            + ".svc.cluster.local:3100/loki/api/v1/push";
        lane = "\ndiscovery.relabel \"" + ident + "\" {\n";
        lane = lane + "  targets = discovery.kubernetes.pods.targets\n\n";
        lane = lane + "  rule {\n";
        lane = lane + "    source_labels = [\"__meta_kubernetes_namespace\"]\n";
        lane = lane + "    regex         = \"" + app_namespace + "\"\n";
        lane = lane + "    action        = \"keep\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  rule {\n";
        lane = lane + "    source_labels = [\"__meta_kubernetes_pod_node_name\"]\n";
        lane = lane + "    target_label  = \"__host__\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  rule {\n";
        lane = lane + "    action = \"labelmap\"\n";
        lane = lane + "    regex  = \"__meta_kubernetes_pod_label_(.+)\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  rule {\n";
        lane = lane + "    source_labels = [\"__meta_kubernetes_namespace\"]\n";
        lane = lane + "    target_label  = \"namespace\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  rule {\n";
        lane = lane + "    source_labels = [\"__meta_kubernetes_pod_name\"]\n";
        lane = lane + "    target_label  = \"pod\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  rule {\n";
        lane = lane
            + "    source_labels = [\"__meta_kubernetes_pod_container_name\"]\n";
        lane = lane + "    target_label  = \"container\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  rule {\n";
        lane = lane + "    action        = \"replace\"\n";
        lane = lane + "    separator     = \"/\"\n";
        lane = lane + "    source_labels = [\n";
        lane = lane + "      \"__meta_kubernetes_pod_uid\",\n";
        lane = lane + "      \"__meta_kubernetes_pod_container_name\",\n";
        lane = lane + "    ]\n";
        lane = lane + "    target_label = \"__path__\"\n";
        lane = lane + "    replacement  = \"/var/log/pods/*$1/*.log\"\n";
        lane = lane + "  }\n";
        lane = lane + "}\n\n";
        lane = lane + "local.file_match \"" + ident + "\" {\n";
        lane = lane + "  path_targets = discovery.relabel." + ident + ".output\n";
        lane = lane + "}\n\n";
        lane = lane + "loki.source.file \"" + ident + "\" {\n";
        lane = lane + "  targets    = local.file_match." + ident + ".targets\n";
        lane = lane + "  forward_to = [loki.process." + ident + ".receiver]\n";
        lane = lane + "}\n\n";
        lane = lane + "loki.process \"" + ident + "\" {\n";
        lane = lane + "  forward_to = [loki.write." + ident + ".receiver]\n\n";
        lane = lane + "  stage.cri {}\n\n";
        lane = lane + "  stage.json {\n";
        lane = lane + "    expressions = {\n";
        lane = lane + "      ts       = \"ts\",\n";
        lane = lane + "      level    = \"level\",\n";
        lane = lane + "      service  = \"service\",\n";
        lane = lane + "      trace_id = \"trace_id\",\n";
        lane = lane + "    }\n";
        lane = lane + "  }\n\n";
        lane = lane + "  stage.timestamp {\n";
        lane = lane + "    source            = \"ts\"\n";
        lane = lane + "    format            = \"RFC3339Nano\"\n";
        lane = lane + "    action_on_failure = \"skip\"\n";
        lane = lane + "  }\n\n";
        lane = lane + "  stage.labels {\n";
        lane = lane + "    values = {\n";
        lane = lane + "      service = \"\",\n";
        lane = lane + "      level   = \"\",\n";
        lane = lane + "    }\n";
        lane = lane + "  }\n";
        lane = lane + "}\n\n";
        lane = lane + "loki.write \"" + ident + "\" {\n";
        lane = lane + "  endpoint {\n";
        lane = lane + "    url = \"" + loki_url + "\"\n";
        lane = lane + "  }\n";
        lane = lane + "}\n";
        return lane;
    }

    def _render_alloy_config(lanes: dict[str, str]) -> str {
        cfg = self._alloy_base_config();
        for key in sorted(lanes.keys()) {
            cfg = cfg + lanes[key];
        }
        return cfg;
    }

    def _put_config_map(core_v1: any, name: str, data: dict[str, str]) {
        attempt = 0;
        while attempt < LANE_WRITE_ATTEMPTS {
            attempt += 1;
            (existing, rv) = self._read_lanes_versioned(core_v1, name);
            if rv and existing == data {
                return;
            }
            try {
                self._write_lanes(core_v1, name, data, rv);
                return;
            } except ApiException as e {
                if e.status != 409 or attempt >= LANE_WRITE_ATTEMPTS {
                    raise;
                }
            }
        }
    }

    def _read_secret_versioned(core_v1: any) -> tuple[dict[str, str], str] {
        ns = self.namespace();
        try {
            found = core_v1.read_namespaced_secret(
                name=SCRAPE_SECRET_NAME, namespace=ns
            );
            meta = found?.metadata;
            rv = str(getattr(meta, 'resource_version', '') or '') if meta else '';
            return (dict(getattr(found, 'data', {}) or {}), rv);
        } except ApiException as e {
            if e.status == 404 {
                return ({}, '');
            }
            raise;
        }
    }

    def _put_scrape_password(core_v1: any, key: str, password: (str | None)) {
        ns = self.namespace();
        attempt = 0;
        while attempt < LANE_WRITE_ATTEMPTS {
            attempt += 1;
            (existing, rv) = self._read_secret_versioned(core_v1);
            if password is None and key not in existing {
                return;
            }
            existing.pop(key, None);
            meta: dict[str, any] = {
                'name': SCRAPE_SECRET_NAME,
                'namespace': ns,
                'labels': dict(SHARED_LABELS)
            };
            if rv {
                meta['resourceVersion'] = rv;
            }
            body: dict[str, any] = {
                'apiVersion': 'v1',
                'kind': 'Secret',
                'metadata': meta,
                'type': 'Opaque',
                'data': existing
            };
            if password is not None {
                body['stringData'] = {key: password};
            }
            try {
                if rv {
                    core_v1.replace_namespaced_secret(
                        name=SCRAPE_SECRET_NAME, namespace=ns, body=body
                    );
                } else {
                    core_v1.create_namespaced_secret(namespace=ns, body=body);
                }
                return;
            } except ApiException as e {
                if e.status not in [409, 404] or attempt >= LANE_WRITE_ATTEMPTS {
                    raise;
                }
            }
        }
    }

    def _ensure_node_exporter(apps_v1: any, core_v1: any) {
        self._ensure_daemonset(
            apps_v1, NODE_EXPORTER_NAME, self._node_exporter_daemonset()
        );
        self._ensure_service(
            core_v1,
            f"{NODE_EXPORTER_NAME}-service",
            {'app': NODE_EXPORTER_NAME},
            [{'name': 'metrics', 'protocol': 'TCP', 'port': 9100, 'targetPort': 9100}]
        );
    }

    def _ensure_kube_state_metrics(apps_v1: any, core_v1: any) {
        sa_name = f"{KSM_NAME}-sa";
        self._ensure_service_account(core_v1, sa_name);
        self._ensure_cluster_role(
            self.cluster_scoped_name('kube-state-metrics'),
            [
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
                },
                {
                    'apiGroups': ['networking.k8s.io'],
                    'resources': ['networkpolicies', 'ingresses'],
                    'verbs': ['list', 'watch']
                }
            ],
            sa_name
        );
        self._ensure_deployment(apps_v1, KSM_NAME, self._ksm_deployment());
        self._ensure_service(
            core_v1,
            f"{KSM_NAME}-service",
            {'app': KSM_NAME},
            [
                {
                    'name': 'http-metrics',
                    'protocol': 'TCP',
                    'port': 8080,
                    'targetPort': 8080
                },
                {
                    'name': 'telemetry',
                    'protocol': 'TCP',
                    'port': 8081,
                    'targetPort': 8081
                }
            ]
        );
    }

    def _ensure_prometheus(apps_v1: any, core_v1: any) {
        sa_name = f"{PROMETHEUS_NAME}-sa";
        self._ensure_service_account(core_v1, sa_name);
        self._ensure_cluster_role(
            self.cluster_scoped_name('prometheus'),
            [
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
            ],
            sa_name
        );
        lanes = self._read_lanes(core_v1, PROMETHEUS_LANES_CM);
        rendered = self._render_prometheus_config(
            lanes, self._node_level_wanted(core_v1)
        );
        self._put_config_map(
            core_v1, f"{PROMETHEUS_NAME}-config", {'prometheus.yml': rendered}
        );
        base_hash = hashlib.md5(self._prometheus_base_config().encode()).hexdigest()[:12];
        self._ensure_deployment(
            apps_v1, PROMETHEUS_NAME, self._prometheus_deployment(base_hash)
        );
        self._ensure_service(
            core_v1,
            f"{PROMETHEUS_NAME}-service",
            {'app': PROMETHEUS_NAME},
            [{'name': 'http', 'protocol': 'TCP', 'port': 9090, 'targetPort': 9090}]
        );
    }

    def _ensure_alloy(apps_v1: any, core_v1: any) {
        sa_name = f"{ALLOY_NAME}-sa";
        self._ensure_service_account(core_v1, sa_name);
        self._ensure_cluster_role(
            self.cluster_scoped_name('alloy'),
            [
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
            ],
            sa_name
        );
        lanes = self._read_lanes(core_v1, ALLOY_LANES_CM);
        rendered = self._render_alloy_config(lanes);
        self._put_config_map(
            core_v1, f"{ALLOY_NAME}-config", {'config.alloy': rendered}
        );
        base_hash = hashlib.md5(self._alloy_base_config().encode()).hexdigest()[:12];
        self._ensure_daemonset(apps_v1, ALLOY_NAME, self._alloy_daemonset(base_hash));
        self._ensure_service(
            core_v1,
            f"{ALLOY_NAME}-service",
            {'app': ALLOY_NAME},
            [{'name': 'http', 'protocol': 'TCP', 'port': 12345, 'targetPort': 12345}]
        );
    }

    def ensure_metrics_tier(apps_v1: any, core_v1: any) {
        self._ensure_namespace(core_v1);
        if self.k8s_config.k8s_metrics_enabled {
            self._ensure_node_exporter(apps_v1, core_v1);
            self._ensure_kube_state_metrics(apps_v1, core_v1);
        }
        self._ensure_prometheus(apps_v1, core_v1);
    }

    def ensure_logs_tier(apps_v1: any, core_v1: any) {
        self._ensure_namespace(core_v1);
        self._ensure_alloy(apps_v1, core_v1);
    }

    def register_app(
        app_name: str,
        app_namespace: str,
        apps_v1: any,
        core_v1: any,
        scrape_target: str,
        service_port: int
    ) {
        key = lane_key(app_name, app_namespace);
        want_metrics = self.k8s_config.monitoring_enabled;
        want_logs = self.k8s_config.loki_enabled;
        if want_metrics {
            self._ensure_namespace(core_v1);
            self._put_scrape_password(
                core_v1, key, self.k8s_config.prometheus_admin_password
            );
            lanes = self._put_lane(
                core_v1,
                PROMETHEUS_LANES_CM,
                key,
                self.prometheus_lane(
                    app_name, app_namespace, scrape_target, service_port
                )
            );
            self.ensure_metrics_tier(apps_v1, core_v1);
            self._put_config_map(
                core_v1,
                f"{PROMETHEUS_NAME}-config",
                {
                    'prometheus.yml': self._render_prometheus_config(
                        lanes, self._node_level_wanted(core_v1)
                    )
                }
            );
            self._log(f"Registered '{app_name}' with the shared Prometheus");
        }
        if want_logs {
            self._ensure_namespace(core_v1);
            lanes = self._put_lane(
                core_v1, ALLOY_LANES_CM, key, self.alloy_lane(app_name, app_namespace)
            );
            self.ensure_logs_tier(apps_v1, core_v1);
            self._put_config_map(
                core_v1,
                f"{ALLOY_NAME}-config",
                {'config.alloy': self._render_alloy_config(lanes)}
            );
            self._log(f"Registered '{app_name}' with the shared Alloy");
        }
    }

    def unregister_app(app_name: str, app_namespace: str, core_v1: any) {
        key = lane_key(app_name, app_namespace);

        if key in self._read_lanes(core_v1, PROMETHEUS_LANES_CM) {
            prom_lanes = self._put_lane(core_v1, PROMETHEUS_LANES_CM, key, None);
            self._put_config_map(
                core_v1,
                f"{PROMETHEUS_NAME}-config",
                {
                    'prometheus.yml': self._render_prometheus_config(
                        prom_lanes, self._node_level_wanted(core_v1)
                    )
                }
            );
        }
        self._put_scrape_password(core_v1, key, None);

        if key in self._read_lanes(core_v1, ALLOY_LANES_CM) {
            alloy_lanes = self._put_lane(core_v1, ALLOY_LANES_CM, key, None);
            self._put_config_map(
                core_v1,
                f"{ALLOY_NAME}-config",
                {'config.alloy': self._render_alloy_config(alloy_lanes)}
            );
        }
        self._log(f"Unregistered '{app_name}' from the shared observability tier");
    }

    def prometheus_url -> str {
        return "http://"
            + PROMETHEUS_NAME
            + "-service."
            + self.namespace()
            + ".svc.cluster.local:9090";
    }
}
