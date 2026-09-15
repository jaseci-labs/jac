import re;
import from jaclang.scale._optdeps.kubernetes { client, ApiException }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    delete_if_exists,
    delete_k8s_secret
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }
import from jaclang.scale.deploy.target.kubernetes.shared_observability {
    SharedObservability
}

obj MonitoringDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None,
        rbac_api: any = None;

    def ensure_service(core_v1: any, name: str, namespace: str, body: dict) {
        try {
            core_v1.read_namespaced_service(name=name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(namespace=namespace, body=body);
            } else {
                raise;
            }
        }
    }

    def _deploy_grafana(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        grafana_name = f"{app_name}-grafana";
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

        share_metrics = self.k8s_config.app_grafana_metrics;
        loki_name = f"{app_name}-loki";
        loki_url = f"http://{loki_name}-service:3100";
        datasource_yaml = "apiVersion: 1\ndatasources:\n";
        if share_metrics {
            prometheus_url = SharedObservability(
                self.k8s_config, self.logger, self.rbac_api
            ).prometheus_url();
            datasource_yaml = datasource_yaml
                + (
                    "  - name: Prometheus\n"
                    "    uid: prometheus\n"
                    "    type: prometheus\n"
                    f"    url: {prometheus_url}\n"
                    "    isDefault: true\n"
                    "    access: proxy\n"
                    "    editable: true\n"
                );
        }
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

        dashboard_data: dict[str, str] = {};
        if share_metrics {
            dashboard_data['jac-scale.json'] = app_dashboard_json;
            if self.k8s_config.k8s_metrics_enabled {
                dashboard_data['k8s-metrics.json'] = k8s_dashboard_json;
            }
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
        self.ensure_service(core_v1, f"{loki_name}-service", namespace, loki_service);

        if self.logger {
            self.logger.info(f"Loki deployed for '{app_name}'");
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
        want_metrics = self.k8s_config.monitoring_enabled;
        want_logs = self.k8s_config.loki_enabled;
        if want_logs {
            self._deploy_loki(app_name, namespace, apps_v1, core_v1);
        }
        if self.k8s_config.tracing_enabled {
            self._deploy_tempo(app_name, namespace, apps_v1, core_v1);
        }
        if want_metrics or want_logs {
            shared = SharedObservability(self.k8s_config, self.logger, self.rbac_api);
            shared.register_app(
                app_name,
                namespace,
                apps_v1,
                core_v1,
                scrape_target_service or f"{app_name}-service",
                provider.prometheus_scrape_port(self.k8s_config.container_port)
            );
        }
        if want_metrics or want_logs or self.k8s_config.tracing_enabled {
            self._deploy_grafana(app_name, namespace, apps_v1, core_v1);
        }
    }

    def _sweep_legacy_collectors(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) {
        prometheus_name = f"{app_name}-prometheus";
        ksm_name = f"{app_name}-kube-state-metrics";
        ne_name = f"{app_name}-node-exporter";
        alloy_name = f"{app_name}-alloy";

        for ds_name in [ne_name, alloy_name] {
            try {
                apps_v1.delete_namespaced_daemon_set(name=ds_name, namespace=namespace);
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }
        }
        for dep_name in [prometheus_name, ksm_name] {
            delete_if_exists(
                apps_v1.delete_namespaced_deployment, dep_name, namespace, 'Deployment'
            );
        }
        for svc in [
            f"{prometheus_name}-service",
            f"{ksm_name}-service",
            f"{ne_name}-service",
            f"{alloy_name}-service"
        ] {
            delete_if_exists(
                core_v1.delete_namespaced_service, svc, namespace, 'Service'
            );
        }
        for cm_name in [f"{prometheus_name}-config", f"{alloy_name}-config"] {
            try {
                core_v1.delete_namespaced_config_map(name=cm_name, namespace=namespace);
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }
        }
        delete_k8s_secret(core_v1, namespace, f"{prometheus_name}-scrape-secret");
        for sa_name in [
            f"{prometheus_name}-sa",
            f"{ksm_name}-sa",
            f"{alloy_name}-sa"
        ] {
            delete_if_exists(
                core_v1.delete_namespaced_service_account,
                sa_name,
                namespace,
                'ServiceAccount'
            );
        }
        rbac_v1 = self.rbac_api
            if self.rbac_api is not None
            else client.RbacAuthorizationV1Api();
        for cluster_name in [
            f"{namespace}-{prometheus_name}",
            f"{namespace}-{ksm_name}",
            f"{namespace}-{alloy_name}"
        ] {
            for remove_fn in [
                rbac_v1.delete_cluster_role,
                rbac_v1.delete_cluster_role_binding
            ] {
                try {
                    remove_fn(name=cluster_name);
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }
        }
    }

    def destroy(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        grafana_name = f"{app_name}-grafana";
        loki_name = f"{app_name}-loki";
        tempo_name = f"{app_name}-tempo";

        shared = SharedObservability(self.k8s_config, self.logger, self.rbac_api);
        shared.unregister_app(app_name, namespace, core_v1);
        self._sweep_legacy_collectors(app_name, namespace, apps_v1, core_v1);

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
            f"{grafana_name}-sa",
            namespace,
            'ServiceAccount'
        );

        if self.logger {
            self.logger.info(f"Monitoring stack destroyed for '{app_name}'");
        }
    }
}
