import from typing { Any }
import from jaclang.runtimelib.client { BUN_VERSION }
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.resource_status { ResourceStatus, ResourceStatusInfo }
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.injector.pvc_injector { PvcInjector, bundle_pvc_name }
import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_bootstrap_init_container,
    runtime_container_env
}
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    COMPANION_DEFS,
    check_deployment_status,
    check_pods_restarted,
    create_k8s_secret,
    delete_k8s_secret,
    delete_if_exists,
    delete_namespace,
    check_K8s_status,
    ensure_namespace_exists,
    ensure_pvc_exists,
    get_cluster_provider,
    load_env_variables,
    validate_resource_limits,
    resize_pvc_if_needed
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }
import from jaclang.scale.deploy.database.kubernetes_mongo { KubernetesMongoProvider }
import from jaclang.scale.deploy.database.kubernetes_redis { KubernetesRedisProvider }
import from jaclang.scale._optdeps.optional_deps { require_optional }
import from jaclang.scale._optdeps.kubernetes {
    client,
    config as k8s_cluster_config,
    ApiException,
    ConfigException
}
import from jaclang.scale.deploy.database.factory { DatabaseProviderFactory }
import from jaclang.scale.deploy.target.kubernetes.monitoring { MonitoringDeployer }
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerSpec,
    Trigger,
    TriggerAuth
}
import time;

obj KubernetesTarget(DeploymentTarget) {
    has config: KubernetesConfig,
        logger: (Logger | None) = None,
        k8s_config: KubernetesConfig postinit,
        env_list: list = [],
        secrets: dict[str, str] = {},
        dry_run: bool = False;

    def postinit {
        self.k8s_config = self.config;
    }

    def _get_database_init_containers(app_name: str) -> list[dict[(str, Any)]] {
        init_containers = [];
        wait_image = self.k8s_config.wait_image;

        if self.k8s_config.mongodb_enabled {
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            init_container = mongo_provider.get_init_container(app_name, wait_image);
            if init_container {
                init_containers.append(init_container);
            }
        }

        if self.k8s_config.redis_enabled {
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', self, {'app_name': app_name}
            );
            init_container = redis_provider.get_init_container(app_name, wait_image);
            if init_container {
                init_containers.append(init_container);
            }
        }

        return init_containers;
    }

    def _build_resource_config -> dict[(str, Any)] {
        resource_requests: dict[(str, str)] = {};
        if self.k8s_config.cpu_request {
            resource_requests['cpu'] = self.k8s_config.cpu_request;
        }
        if self.k8s_config.memory_request {
            resource_requests['memory'] = self.k8s_config.memory_request;
        }

        resource_limits: dict[(str, str)] = {};
        if self.k8s_config.cpu_limit {
            resource_limits['cpu'] = self.k8s_config.cpu_limit;
        }
        if self.k8s_config.memory_limit {
            resource_limits['memory'] = self.k8s_config.memory_limit;
        }

        resources: dict[(str, dict)] = {};
        if resource_requests {
            resources['requests'] = resource_requests;
        }
        if resource_limits {
            resources['limits'] = resource_limits;
        }

        return resources;
    }

    def _build_probe_config(health_check_path: str) -> dict[(str, Any)] {
        probe_config = {
            'httpGet': {
                'path': health_check_path,
                'port': self.k8s_config.container_port,
                'scheme': 'HTTP'
            },
            'initialDelaySeconds': self.k8s_config.readiness_initial_delay,
            'periodSeconds': self.k8s_config.readiness_period
        };

        liveness_probe = dict(probe_config);
        liveness_probe['initialDelaySeconds'] = self.k8s_config.liveness_initial_delay;
        liveness_probe['periodSeconds'] = self.k8s_config.liveness_period;
        liveness_probe['failureThreshold'] = self.k8s_config.liveness_failure_threshold;

        startup_probe = {
            'httpGet': {
                'path': health_check_path,
                'port': self.k8s_config.container_port,
                'scheme': 'HTTP'
            },
            'initialDelaySeconds': 10,
            'periodSeconds': 10,
            'failureThreshold': 90
        };

        return {
            'readiness': probe_config,
            'liveness': liveness_probe,
            'startup': startup_probe
        };
    }

    def _build_service_config(
        app_name: str, health_check_path: str
    ) -> dict[(str, Any)] {
        service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {
                'name': f"{app_name}-service",
                'namespace': self.k8s_config.namespace,
                'labels': {'app': app_name, 'managed': 'jac-scale'}
            },
            'spec': {
                'type': 'ClusterIP',
                'ports': [
                    {
                        'protocol': 'TCP',
                        'port': self.k8s_config.container_port,
                        'targetPort': self.k8s_config.container_port
                    }
                ],
                'selector': {'app': app_name}
            }
        };

        return service;
    }

    def _build_runtime_setup_command(app_config: AppConfig) -> list[str] {
        import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
            build_service_apt_prefix
        }
        apt_prefix = build_service_apt_prefix(self.k8s_config);
        commands = [
            f"cd {self.k8s_config.app_mount_path}",
            f"jac start {app_config.file_name}"
        ];
        script = ' && '.join(commands);
        return ['bash', '-c', apt_prefix + script];
    }

    def _build_container_config(
        app_name: str,
        image: str,
        probe_configs: dict[(str, Any)],
        resources_config: dict[(str, Any)],
        command: (list[str] | None) = None,
        working_dir: (str | None) = None,
        volume_mounts: (list[dict[(str, Any)]] | None) = None,
        secret_ref_name: (str | None) = None,
        needs_root: bool = False
    ) -> dict[(str, Any)] {
        if needs_root {
            security_context = {
                'readOnlyRootFilesystem': False,
                'allowPrivilegeEscalation': False,
                'capabilities': {
                    'drop': ['ALL'],
                    'add': [
                        'CHOWN',
                        'DAC_OVERRIDE',
                        'FOWNER',
                        'FSETID',
                        'SETUID',
                        'SETGID'
                    ]
                },
                'seccompProfile': {'type': 'RuntimeDefault'}
            };
        } else {
            security_context = {
                'runAsNonRoot': True,
                'runAsUser': 1000,
                'readOnlyRootFilesystem': True,
                'allowPrivilegeEscalation': False,
                'capabilities': {'drop': ['ALL']},
                'seccompProfile': {'type': 'RuntimeDefault'}
            };
        }
        container_config = {
            'name': app_name,
            'image': image,
            'securityContext': security_context,
            'ports': [{'containerPort': self.k8s_config.container_port}],
            'env': self.env_list,
            'readinessProbe': probe_configs['readiness'],
            'livenessProbe': probe_configs['liveness'],
            'startupProbe': probe_configs['startup']
        };

        if secret_ref_name {
            container_config['envFrom'] = [{'secretRef': {'name': secret_ref_name}}];
        }
        if command {
            container_config['command'] = command;
        }
        if working_dir {
            container_config['workingDir'] = working_dir;
        }
        if volume_mounts {
            container_config['volumeMounts'] = volume_mounts;
        }
        if resources_config {
            container_config['resources'] = resources_config;
        }

        return container_config;
    }

    def _deploy_databases(app_name: str, namespace: str, apps_v1: Any, core_v1: Any) {
        if self.k8s_config.mongodb_enabled {
            mongodb_name = f"{app_name}-mongodb";
            mongodb_service_name = f"{mongodb_name}-service";
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            mongo_result = mongo_provider.deploy({});
            self._apply_provider_service_account(
                mongo_result['service_account'], namespace, core_v1
            );
            self.env_list.append(
                {
                    'name': 'MONGODB_URI',
                    'valueFrom': {
                        'secretKeyRef': {
                            'name': mongo_result['secret_name'],
                            'key': 'connection-string'
                        }
                    }
                }
            );
            try {
                core_v1.read_namespaced_secret(
                    name=mongo_result['secret']['metadata']['name'], namespace=namespace
                );
            } except ApiException as e {
                if e.status == 404 {
                    core_v1.create_namespaced_secret(
                        namespace=namespace, body=mongo_result['secret']
                    );
                } else {
                    raise;
                }
            }
            try {
                apps_v1.read_namespaced_stateful_set(
                    name=mongodb_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    apps_v1.create_namespaced_stateful_set(
                        namespace=namespace, body=mongo_result['deployment']
                    );
                } else {
                    raise;
                }
            }
            mongodb_volume_name = f"{app_name}-mongo-data";
            mongodb_pvc_name = f"{mongodb_volume_name}-{mongodb_name}-0";
            resize_pvc_if_needed(
                core_v1,
                namespace,
                mongodb_pvc_name,
                self.k8s_config.mongodb_storage_size
            );
            try {
                core_v1.read_namespaced_service(
                    name=mongodb_service_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=mongo_result['service']
                    );
                } else {
                    raise;
                }
            }
            if self.k8s_config.mongodb_dashboard {
                express_result = mongo_provider.deploy_dashboard(
                    username=self.k8s_config.mongo_express_username,
                    password=self.k8s_config.mongo_express_password
                );
                self._apply_provider_service_account(
                    express_result['service_account'], namespace, core_v1
                );
                try {
                    apps_v1.patch_namespaced_deployment(
                        name=express_result['deployment_name'],
                        namespace=namespace,
                        body=express_result['deployment']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        apps_v1.create_namespaced_deployment(
                            namespace=namespace, body=express_result['deployment']
                        );
                    } else {
                        raise;
                    }
                }
                try {
                    core_v1.patch_namespaced_service(
                        name=express_result['service_name'],
                        namespace=namespace,
                        body=express_result['service']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        core_v1.create_namespaced_service(
                            namespace=namespace, body=express_result['service']
                        );
                    } else {
                        raise;
                    }
                }
                if self.logger {
                    self.logger.info(
                        f"mongo-express dashboard deployed for '{app_name}' (accessible via ingress at /db-dashboard)"
                    );
                }
            }
        }

        if self.k8s_config.redis_enabled {
            redis_name = f"{app_name}-redis";
            redis_service_name = f"{redis_name}-service";
            redis_config_name = f"{redis_name}-config";
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', self, {'app_name': app_name}
            );
            redis_result = redis_provider.deploy({});
            self._apply_provider_service_account(
                redis_result['service_account'], namespace, core_v1
            );
            self.env_list.append(
                {
                    'name': 'REDIS_URL',
                    'valueFrom': {
                        'secretKeyRef': {
                            'name': redis_result['secret_name'],
                            'key': 'connection-string'
                        }
                    }
                }
            );
            try {
                core_v1.read_namespaced_secret(
                    name=redis_result['secret']['metadata']['name'], namespace=namespace
                );
            } except ApiException as e {
                if e.status == 404 {
                    core_v1.create_namespaced_secret(
                        namespace=namespace, body=redis_result['secret']
                    );
                } else {
                    raise;
                }
            }
            config_updated = False;
            try {
                existing_cm = core_v1.read_namespaced_config_map(
                    name=redis_config_name, namespace=namespace
                );
                existing_content = existing_cm.data.get('redis.conf', '');
                new_content = redis_result['configmap']['data']['redis.conf'];

                if existing_content != new_content {
                    if self.logger {
                        self.logger.info(
                            f"Redis configuration changed (hash: {redis_result[
                                'config_hash'
                            ]}). "
                            "Updating ConfigMap..."
                        );
                    }
                    core_v1.replace_namespaced_config_map(
                        name=redis_config_name,
                        namespace=namespace,
                        body=redis_result['configmap']
                    );
                    config_updated = True;
                    if self.logger {
                        self.logger.info("Redis ConfigMap updated successfully");
                    }
                } else {
                    if self.logger {
                        self.logger.debug(
                            "Redis configuration unchanged, skipping ConfigMap update"
                        );
                    }
                }
            } except ApiException as e {
                if (e.status == 404) {
                    if self.logger {
                        self.logger.info("Creating new Redis ConfigMap");
                    }
                    core_v1.create_namespaced_config_map(
                        namespace=namespace, body=redis_result['configmap']
                    );
                    if self.logger {
                        self.logger.info("Redis ConfigMap created successfully");
                    }
                } else {
                    if self.logger {
                        self.logger.error(f"Failed to manage Redis ConfigMap: {e}");
                    }
                    raise;
                }
            }

            try {
                existing_deploy = apps_v1.read_namespaced_deployment(
                    name=redis_name, namespace=namespace
                );

                annotations = existing_deploy.spec.template.metadata.annotations;
                existing_hash = annotations.get('redis-config-hash', '')
                    if annotations
                    else '';
                new_hash = redis_result['config_hash'];

                if existing_hash != new_hash or config_updated {
                    if self.logger {
                        self.logger.info(
                            f"Redis deployment needs update. "
                            f"Old hash: {existing_hash}, New hash: {new_hash}"
                        );
                    }

                    apps_v1.replace_namespaced_deployment(
                        name=redis_name,
                        namespace=namespace,
                        body=redis_result['deployment']
                    );
                    if self.logger {
                        self.logger.info(
                            "Redis deployment updated. Pods will restart with new configuration."
                        );
                    }
                } else {
                    if self.logger {
                        self.logger.debug(
                            "Redis deployment unchanged, skipping update"
                        );
                    }
                }
            } except ApiException as e {
                if (e.status == 404) {
                    if self.logger {
                        self.logger.info("Creating new Redis deployment");
                    }
                    apps_v1.create_namespaced_deployment(
                        namespace=namespace, body=redis_result['deployment']
                    );
                    if self.logger {
                        self.logger.info("Redis deployment created successfully");
                    }
                } else {
                    if self.logger {
                        self.logger.error(f"Failed to manage Redis deployment: {e}");
                    }
                    raise;
                }
            }

            try {
                core_v1.read_namespaced_service(
                    name=redis_service_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=redis_result['service']
                    );
                } else {
                    raise;
                }
            }
            if self.k8s_config.redis_dashboard {
                insight_result = redis_provider.deploy_dashboard();
                self._apply_provider_service_account(
                    insight_result['service_account'], namespace, core_v1
                );
                try {
                    apps_v1.patch_namespaced_deployment(
                        name=insight_result['deployment_name'],
                        namespace=namespace,
                        body=insight_result['deployment']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        apps_v1.create_namespaced_deployment(
                            namespace=namespace, body=insight_result['deployment']
                        );
                    } else {
                        raise;
                    }
                }
                try {
                    core_v1.patch_namespaced_service(
                        name=insight_result['service_name'],
                        namespace=namespace,
                        body=insight_result['service']
                    );
                } except ApiException as e {
                    if e.status == 404 {
                        core_v1.create_namespaced_service(
                            namespace=namespace, body=insight_result['service']
                        );
                    } else {
                        raise;
                    }
                }
                if self.logger {
                    self.logger.info(
                        f"RedisInsight dashboard deployed for '{app_name}' (accessible via ingress at /cache-dashboard)"
                    );
                }
            }
        }
    }

    def _create_service_account(
        sa_name: str, app_label: str, namespace: str, core_v1: any
    ) {
        sa_body = {
            'apiVersion': 'v1',
            'kind': 'ServiceAccount',
            'metadata': {
                'name': sa_name,
                'namespace': namespace,
                'labels': {'app': app_label, 'managed': 'jac-scale'}
            },
            'automountServiceAccountToken': False
        };
        try {
            core_v1.read_namespaced_service_account(name=sa_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=sa_body
                );
                if self.logger {
                    self.logger.info(
                        f"Created ServiceAccount '{sa_name}' in namespace '{namespace}'"
                    );
                }
            } else {
                raise;
            }
        }
    }

    def _apply_provider_service_account(
        sa_spec: dict[str, any], namespace: str, core_v1: any
    ) {
        sa_spec['metadata']['namespace'] = namespace;
        sa_name = sa_spec['metadata']['name'];
        try {
            core_v1.read_namespaced_service_account(name=sa_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service_account(
                    namespace=namespace, body=sa_spec
                );
                if self.logger {
                    self.logger.info(
                        f"Created ServiceAccount '{sa_name}' in namespace '{namespace}'"
                    );
                }
            } else {
                raise;
            }
        }
    }

    def _deploy_network_policy(app_name: str, namespace: str, networking_v1: any) {
        common_egress_rules = [
            {
                'to': [
                    {
                        'namespaceSelector': {
                            'matchLabels': {
                                'kubernetes.io/metadata.name': 'kube-system'
                            }
                        }
                    }
                ],
                'ports': [
                    {'protocol': 'UDP', 'port': 53},
                    {'protocol': 'TCP', 'port': 53}
                ]
            },
            {'to': [{'podSelector': {}}]},
            {
                'ports': [
                    {'protocol': 'TCP', 'port': 443},
                    {'protocol': 'TCP', 'port': 80}
                ]
            }
        ];

        policies = [
            {
                'name': f"{app_name}-network-policy",
                'pod_selector': {'matchLabels': {'app': app_name}},
                'ingress_rules': [
                    {
                        'ports': [
                            {'protocol': 'TCP', 'port': self.k8s_config.container_port}
                        ]
                    }
                ]
            },
            {
                'name': f"{app_name}-mongodb-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-mongodb"}},
                'ingress_rules': [
                    {
                        'from': [
                            {'podSelector': {'matchLabels': {'app': app_name}}},
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-mongo-express"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 27017}]
                    }
                ]
            },
            {
                'name': f"{app_name}-redis-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-redis"}},
                'ingress_rules': [
                    {
                        'from': [
                            {'podSelector': {'matchLabels': {'app': app_name}}},
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-redis-insight"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 6379}]
                    }
                ]
            },
            {
                'name': f"{app_name}-prometheus-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-prometheus"}},
                'ingress_rules': [
                    {
                        'from': [
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-grafana"}
                                }
                            },
                            {'podSelector': {'matchLabels': {'app': app_name}}}
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 9090}]
                    }
                ]
            },
            {
                'name': f"{app_name}-grafana-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-grafana"}},
                'ingress_rules': [{'ports': [{'protocol': 'TCP', 'port': 3000}]}]
            },
            {
                'name': f"{app_name}-kube-state-metrics-network-policy",
                'pod_selector': {
                    'matchLabels': {'app': f"{app_name}-kube-state-metrics"}
                },
                'ingress_rules': [
                    {
                        'from': [
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-prometheus"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 8080}]
                    }
                ]
            },
            {
                'name': f"{app_name}-node-exporter-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-node-exporter"}},
                'ingress_rules': [
                    {
                        'from': [
                            {
                                'podSelector': {
                                    'matchLabels': {'app': f"{app_name}-prometheus"}
                                }
                            }
                        ],
                        'ports': [{'protocol': 'TCP', 'port': 9100}]
                    }
                ]
            },
            {
                'name': f"{app_name}-mongo-express-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-mongo-express"}},
                'ingress_rules': [{'ports': [{'protocol': 'TCP', 'port': 8081}]}]
            },
            {
                'name': f"{app_name}-redis-insight-network-policy",
                'pod_selector': {'matchLabels': {'app': f"{app_name}-redis-insight"}},
                'ingress_rules': [{'ports': [{'protocol': 'TCP', 'port': 5540}]}]
            }
        ];

        for policy_config in policies {
            network_policy = {
                'apiVersion': 'networking.k8s.io/v1',
                'kind': 'NetworkPolicy',
                'metadata': {
                    'name': policy_config['name'],
                    'namespace': namespace,
                    'labels': {'app': app_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'podSelector': policy_config['pod_selector'],
                    'policyTypes': ['Ingress', 'Egress'],
                    'ingress': policy_config['ingress_rules'],
                    'egress': common_egress_rules
                }
            };

            try {
                networking_v1.read_namespaced_network_policy(
                    name=policy_config['name'], namespace=namespace
                );
                networking_v1.replace_namespaced_network_policy(
                    name=policy_config['name'], namespace=namespace, body=network_policy
                );
            } except ApiException as e {
                if e.status == 404 {
                    networking_v1.create_namespaced_network_policy(
                        namespace=namespace, body=network_policy
                    );
                    if self.logger {
                        self.logger.info(
                            f"Created NetworkPolicy '{policy_config[
                                'name'
                            ]}' in namespace '{namespace}'"
                        );
                    }
                } else {
                    raise;
                }
            }
        }
    }

    def _wait_for_deployment(
        app_name: str, namespace: str, health_check_path: str, provider: ClusterProvider
    ) -> str {
        path = health_check_path;
        deployment_details = "";

        if self.k8s_config.shared_ingress {
            if self.k8s_config.shared_ingress_skip_reachability {
                if self.logger {
                    self.logger.info(
                        f"Shared ingress mode: skipping reachability probe for "
                        f"'{self.k8s_config.domain}' (DNS is pointed post-deploy)."
                    );
                }

                if check_pods_restarted(namespace, app_name) {
                    raise Exception(
                        "Deployment failed: application pods are restarting "
                        "(crash loop / bad image); not marking the deploy ready."
                    );
                }
                return (
                    "Shared ingress: reachability probe skipped (pods healthy); "
                    "point DNS at the shared controller to finish DNS/TLS."
                );
            }
            domain_url = f"http://{self.k8s_config.domain}";
            if self.logger {
                self.logger.info(
                    f"Shared ingress mode: checking reachability at {domain_url}{path}"
                );
            }
            (domain_status, domain_details) = check_deployment_status(
                self.k8s_config.ingress_node_port,
                path,
                max_retries=48,
                nlb_url=domain_url,
                namespace=namespace,
                app_name=app_name
            );
            if not domain_status {
                if provider.needs_nlb_wait() {
                    dns_hint = (
                        f"Add a CNAME record for '{self.k8s_config.domain}' "
                        "pointing to the shared ingress controller's NLB hostname."
                    );
                } else {
                    dns_hint = (
                        f"Add an A record for '{self.k8s_config.domain}' "
                        "pointing to the shared ingress controller's node IP."
                    );
                }
                if self.logger {
                    self.logger.warn(
                        f"Health check against '{domain_url}{path}' did not succeed. "
                        "This is expected if DNS has not propagated yet. "
                        f"The application pods are healthy. {dns_hint}"
                    );
                }

                return (
                    f"Warning: DNS not propagated yet - health check skipped. {dns_hint}"
                );
            }
            return domain_details;
        }

        if provider.needs_nlb_wait() {
            time.sleep(self.k8s_config.aws_nlb_wait);
            nlb_url = None;
            try {
                try {
                    k8s_cluster_config.load_kube_config();
                } except ConfigException {
                    k8s_cluster_config.load_incluster_config();
                }
                core_v1 = client.CoreV1Api();

                ingress_svc_name = f"{app_name}-ingress-nginx-service";
                service_obj = core_v1.read_namespaced_service(
                    ingress_svc_name, namespace
                );
                nlb_ingress = service_obj.status.load_balancer.ingress;
                if (nlb_ingress and (len(nlb_ingress) > 0)) {
                    endpoint = nlb_ingress[0].hostname or nlb_ingress[0].ip;
                    nlb_url = f"http://{endpoint}";
                } else {
                    if self.logger {
                        self.logger.info(
                            f"NLB is being provisioned. Run 'kubectl get svc {ingress_svc_name} -n {namespace}' to get the endpoint."
                        );
                    }
                }
            } except Exception as e {
                if self.logger {
                    self.logger.warn(f"Could not retrieve NLB endpoint: {e}");
                }
            }
            if (nlb_url) {
                (deployment_status, deployment_details) = check_deployment_status(
                    self.k8s_config.ingress_node_port,
                    path,
                    max_retries=48,
                    nlb_url=nlb_url,
                    namespace=namespace,
                    app_name=app_name
                );
                if not (deployment_status) {
                    raise Exception("Deployment failed: Application failed to deploy.");
                }
            }
        } else {
            (deployment_status, deployment_details) = check_deployment_status(
                self.k8s_config.ingress_node_port,
                path,
                namespace=namespace,
                app_name=app_name
            );
            if deployment_status is False {
                raise Exception(f"Deployment failed: {deployment_details}");
            }
        }
        return deployment_details;
    }

    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        namespace = self.k8s_config.namespace;
        success_status = False;
        details = {};

        if self.logger {
            self.logger.info(
                f"Deploying application '{app_name}' to Kubernetes",
                {'namespace': namespace}
            );
        }
        import from jaclang.scale.injector.binary { resolve_pod_base_image }
        self.k8s_config.python_image = resolve_pod_base_image(
            app_config.code_folder, self.k8s_config.python_image
        );

        try {
            validate_resource_limits(
                self.k8s_config.cpu_request,
                self.k8s_config.cpu_limit,
                self.k8s_config.memory_request,
                self.k8s_config.memory_limit
            );
            details["validate_resource_limits"] = "Successful";
            if self.k8s_config.shared_ingress and not self.k8s_config.domain {
                raise Exception(
                    "shared_ingress=True requires 'domain' to be set so the shared controller "
                    "can route requests by host. Set 'domain' in KubernetesConfig "
                    "(e.g. myapp.example.com)."
                );
            }
            details["validate_shared_ingress"] = "Successful";

            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            networking_v1 = client.NetworkingV1Api();
            check_K8s_status();
            ensure_namespace_exists(namespace);

            self.env_list = load_env_variables(app_config.code_folder);

            self.env_list.append({"name": "K8S_APP_NAME", "value": app_name});
            self.env_list.append({"name": "K8S_NAMESPACE", "value": namespace});
            details["load_env_variables"] = "Successful";

            secret_ref_name: str | None = None;
            if self.secrets {
                secret_ref_name = f"{app_name}-secrets";
                if create_k8s_secret(
                    core_v1, namespace, secret_ref_name, self.secrets
                ) {
                    if self.logger {
                        self.logger.info(f"Created K8s Secret '{secret_ref_name}'");
                    }
                } else {
                    secret_ref_name = None;
                }
            }

            provider = get_cluster_provider();

            if not self.k8s_config.shared_ingress {
                provider.validate_ports(
                    node_port=self.k8s_config.ingress_node_port,
                    current_namespace=namespace
                );
            }

            health_check_path = self.k8s_config.health_check_path;

            init_containers = self._get_database_init_containers(app_name);

            resources_config = self._build_resource_config();
            probe_configs = self._build_probe_config(health_check_path);

            import from jaclang.scale.injector.binary_injector { select_injector }
            (injector, _tc_key) = select_injector(
                self.k8s_config.bundle_storage_class,
                app_name,
                namespace,
                app_config.code_folder,
                provisioned_database=(
                    "mongo" if self.k8s_config.mongodb_enabled else ""
                )
            );
            ensure_pvc_exists(
                core_v1,
                namespace,
                bundle_pvc_name(app_name),
                injector.size,
                storage_class=injector.storage_class or None,
                access_mode='ReadWriteMany'
            );
            injector.seed(app_name, namespace);
            details["ship_source_bundle"] = "Successful";

            command = self._build_runtime_setup_command(app_config);
            container_config = self._build_container_config(
                app_name,
                self.k8s_config.python_image,
                probe_configs,
                resources_config,
                command=command,
                working_dir=self.k8s_config.app_mount_path,
                secret_ref_name=secret_ref_name,
                needs_root=True
            );
            container_config['env'] = container_config['env'] + runtime_container_env();
            import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
                image_pull_policy
            }
            pull_policy = image_pull_policy(self.k8s_config.python_image);
            if pull_policy {
                container_config['imagePullPolicy'] = pull_policy;
            }

            app_sa_name = f"{app_name}-sa";
            self._create_service_account(app_sa_name, app_name, namespace, core_v1);
            details["create_service_account"] = "Successful";

            service = self._build_service_config(app_name, health_check_path);
            deployment = {
                'apiVersion': 'apps/v1',
                'kind': 'Deployment',
                'metadata': {
                    'name': app_name,
                    'namespace': namespace,
                    'labels': {'app': app_name, 'managed': 'jac-scale'}
                },
                'spec': {
                    'replicas': 1,
                    'selector': {'matchLabels': {'app': app_name}},
                    'template': {
                        'metadata': {'labels': {'app': app_name}},
                        'spec': {
                            'automountServiceAccountToken': False,
                            'serviceAccountName': app_sa_name,
                            'securityContext': {
                                'seccompProfile': {'type': 'RuntimeDefault'}
                            },
                            'initContainers': init_containers,
                            'containers': [container_config],
                            'volumes': []
                        }
                    }
                }
            };

            template_spec = deployment['spec']['template']['spec'];
            template_spec['_jac_meta'] = {'app_name': app_name, 'namespace': namespace};
            template_spec = injector.mutate_pod_spec(
                template_spec, self.k8s_config.python_image
            );
            template_spec.pop('_jac_meta', None);

            template_spec['initContainers'].append(
                build_bootstrap_init_container(
                    self.k8s_config, self.k8s_config.python_image
                )
            );
            deployment['spec']['template']['spec'] = template_spec;

            delete_if_exists(
                apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
            );
            details["delete_previous_existing_resources"] = "Successful";
            time.sleep(self.k8s_config.resource_deletion_wait);

            rbac_v1 = client.RbacAuthorizationV1Api();
            networking_v1 = client.NetworkingV1Api();
            ingress_deployer = IngressDeployer(self.k8s_config, self.logger);
            ingress_deployer.start_controller(
                app_name, namespace, provider, apps_v1, core_v1, rbac_v1, networking_v1
            );

            self._deploy_databases(app_name, namespace, apps_v1, core_v1);
            details["deploy_databases"] = "Successful";

            self._deploy_network_policy(app_name, namespace, networking_v1);
            details["deploy_network_policy"] = "Successful";

            if self.logger {
                self.logger.info(f'Deploying Jaseci-app app...');
            }
            apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment);
            details["create_jaseci_application_deployment"] = "Successful";
            try {
                core_v1.read_namespaced_service(
                    name=f"{app_name}-service", namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    core_v1.create_namespaced_service(
                        namespace=namespace, body=service
                    );
                } else {
                    raise;
                }
            }
            details["create_jaseci_application_service"] = "Successful";

            triggers = [];
            if not self.k8s_config.extra_triggers {
                triggers = [
                    Trigger(
                        type="cpu",
                        metadata={
                            "averageUtilization": str(
                                self.k8s_config.cpu_utilization_target
                            )
                        }
                    )
                ];

                if self.k8s_config.memory_request {
                    triggers.append(
                        Trigger(
                            type="memory",
                            metadata={
                                "averageUtilization": str(
                                    self.k8s_config.memory_utilization_target
                                )
                            }
                        )
                    );
                }
            }
            for raw in self.k8s_config.extra_triggers {
                t = Trigger(
                    type=str(raw.get("type", "")),
                    metadata=dict(raw.get("metadata", {})),
                    name=raw.get("name")
                );
                if t.type == "memory" and not self.k8s_config.memory_request {
                    if self.logger {
                        self.logger.warn(
                            "Skipping 'memory' trigger: memory_request is unset; "
                            "HPA cannot compute memory utilization without a "
                            "request baseline"
                        );
                    }
                    continue;
                }
                raw_auth = raw.get("auth");
                if raw_auth {
                    t.auth = TriggerAuth(
                        secret_refs=dict(raw_auth.get("secret_refs", {}))
                    );
                }
                triggers.append(t);
            }
            autoscaler_applied = AutoscalerFactory.create(
                self.k8s_config.autoscaler_engine,
                self.k8s_config.to_dict(),
                self.logger
            ).apply(
                AutoscalerSpec(
                    scale_target_name=app_name,
                    namespace=namespace,
                    min_replicas=self.k8s_config.min_replicas,
                    max_replicas=self.k8s_config.max_replicas,
                    idle_replicas=self.k8s_config.idle_replicas,
                    polling_interval=self.k8s_config.autoscaler_polling_interval,
                    cooldown_period=self.k8s_config.autoscaler_cooldown,
                    initial_cooldown_period=self.k8s_config.autoscaler_initial_cooldown,
                    scale_up_stabilization=self.k8s_config.autoscaler_scale_up_stabilization,
                    scale_up_max_pods=self.k8s_config.autoscaler_scale_up_max_pods,
                    triggers=triggers
                )
            );

            details["create_horizontal_auto_scaler"] = "Successful"
                if autoscaler_applied
                else "Skipped: autoscaler engine not available on cluster";

            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.deploy(app_name, namespace, apps_v1, core_v1, provider);
            details["deploy_monitoring"] = "Successful";

            ingress_deployer.finish_ingress(
                app_name,
                namespace,
                self.k8s_config.container_port,
                self.k8s_config.monitoring_enabled,
                self.k8s_config.redis_dashboard,
                self.k8s_config.mongodb_dashboard,
                apps_v1,
                core_v1,
                networking_v1
            );
            details["deploy_ingress"] = "Successful";

            deployment_details = self._wait_for_deployment(
                app_name, namespace, health_check_path, provider
            );
            details["health_check_of_deployment"] = deployment_details;
            service_url = self.get_service_url(app_name);

            if self.k8s_config.domain {
                lb_endpoint = self._get_lb_endpoint(app_name);
                if lb_endpoint and self.logger {
                    import re;
                    is_ip = bool(re.match(r'^\d+\.\d+\.\d+\.\d+$', lb_endpoint));
                    record_type = "A" if is_ip else "CNAME";
                    self.logger.info(f"\n{'=' * 62}");
                    self.logger.info(
                        f"ACTION REQUIRED - add a {record_type} record in your DNS provider:"
                    );
                    self.logger.info(f"  Type   : {record_type}");
                    self.logger.info(f"  Name   : {self.k8s_config.domain}");
                    self.logger.info(f"  Value  : {lb_endpoint}");
                    self.logger.info(
                        f"\nAfter the record propagates, enable HTTPS with:"
                    );
                    self.logger.info(
                        f"  jac start <your-app.jac> --scale --enable-tls"
                    );
                    self.logger.info(f"{'=' * 62}\n");
                }
            }

            success_status = True;
            return DeploymentResult(
                success=success_status,
                service_url=service_url,
                message=f"Application '{app_name}' deployed successfully",
                details=details
            );
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Error deploying application '{app_name}': {e}");
            }
            return DeploymentResult(
                success=success_status,
                message=f"Deployment failed for application '{app_name}': {e}",
                details=details
            );
        }
    }

    def _wait_for_deletion(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        max_wait: int = 60,
        poll_interval: float = 1.0
    ) -> None {
        elapsed = 0.0;
        while elapsed < max_wait {
            resources_exist = False;

            try {
                apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace);
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            try {
                core_v1.read_namespaced_service(
                    name=f"{app_name}-service", namespace=namespace
                );
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            if self.k8s_config.mongodb_enabled {
                mongodb_name = f"{app_name}-mongodb";
                try {
                    apps_v1.read_namespaced_stateful_set(
                        name=mongodb_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{mongodb_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }

            if self.k8s_config.redis_enabled {
                redis_name = f"{app_name}-redis";
                try {
                    apps_v1.read_namespaced_deployment(
                        name=redis_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{redis_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }

            if self.k8s_config.monitoring_enabled {
                prometheus_name = f"{app_name}-prometheus";
                try {
                    apps_v1.read_namespaced_deployment(
                        name=prometheus_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{prometheus_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                grafana_name = f"{app_name}-grafana";
                try {
                    apps_v1.read_namespaced_deployment(
                        name=grafana_name, namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
                try {
                    core_v1.read_namespaced_service(
                        name=f"{grafana_name}-service", namespace=namespace
                    );
                    resources_exist = True;
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }

            try {
                pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
                for pvc in pvcs.items {
                    if pvc.metadata.name.startswith(app_name) {
                        resources_exist = True;
                        break;
                    }
                }
            } except Exception as e {
                if self.logger {
                    self.logger.warning(
                        f"Failed to list PVCs while checking resources for '{app_name}': {e}"
                    );
                }
            }

            try {
                core_v1.read_namespaced_pod(
                    name=f"{app_name}-code-sync", namespace=namespace
                );
                resources_exist = True;
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
            }

            if not resources_exist {
                if self.logger {
                    self.logger.info(
                        f"All resources for '{app_name}' have been deleted"
                    );
                }
                return;
            }
            time.sleep(poll_interval);
            elapsed = elapsed + poll_interval;
        }

        if self.logger {
            self.logger.warn(
                f"Timeout waiting for resources to be deleted after {max_wait} seconds"
            );
        }
    }

    def _destroy_databases(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        self._destroy_database(app_name, namespace, apps_v1, core_v1);
        self._destroy_cache(app_name, namespace, apps_v1, core_v1);
        self._destroy_dashboard(app_name, namespace, apps_v1, core_v1);
    }

    def _destroy_application(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) {
        autoscaler = AutoscalerFactory.create(
            self.k8s_config.autoscaler_engine, self.k8s_config.to_dict(), self.logger
        );
        autoscaler.destroy(autoscaler.resource_name_for(app_name), namespace);
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{app_name}-service",
            namespace,
            'Service'
        );
        delete_k8s_secret(core_v1, namespace, f"{app_name}-secrets");

        delete_if_exists(
            core_v1.delete_namespaced_pod, f"{app_name}-bundle-loader", namespace, 'Pod'
        );
        delete_if_exists(
            core_v1.delete_namespaced_persistent_volume_claim,
            bundle_pvc_name(app_name),
            namespace,
            'PersistentVolumeClaim'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-sa",
            namespace,
            'ServiceAccount'
        );
        networking_v1 = client.NetworkingV1Api();

        network_policy_names = [
            f"{app_name}-network-policy",
            f"{app_name}-mongodb-network-policy",
            f"{app_name}-redis-network-policy",
            f"{app_name}-prometheus-network-policy",
            f"{app_name}-grafana-network-policy",
            f"{app_name}-kube-state-metrics-network-policy",
            f"{app_name}-node-exporter-network-policy",
            f"{app_name}-mongo-express-network-policy",
            f"{app_name}-redis-insight-network-policy"
        ];
        for policy_name in network_policy_names {
            delete_if_exists(
                networking_v1.delete_namespaced_network_policy,
                policy_name,
                namespace,
                'NetworkPolicy'
            );
        }
    }

    def _destroy_database(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        mongodb_name = f"{app_name}-mongodb";
        delete_if_exists(
            apps_v1.delete_namespaced_stateful_set,
            mongodb_name,
            namespace,
            'StatefulSet'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{mongodb_name}-service",
            namespace,
            'Service'
        );
        delete_k8s_secret(core_v1, namespace, f"{app_name}-mongodb-secret");
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-mongodb-sa",
            namespace,
            'ServiceAccount'
        );
    }

    def _destroy_cache(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        redis_name = f"{app_name}-redis";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, redis_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{redis_name}-service",
            namespace,
            'Service'
        );
        delete_if_exists(
            core_v1.delete_namespaced_config_map,
            f"{redis_name}-config",
            namespace,
            'ConfigMap'
        );
        delete_k8s_secret(core_v1, namespace, f"{app_name}-redis-secret");
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-redis-sa",
            namespace,
            'ServiceAccount'
        );
    }

    def _destroy_dashboard(app_name: str, namespace: str, apps_v1: any, core_v1: any) {
        express_name = f"{app_name}-mongo-express";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, express_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{express_name}-service",
            namespace,
            'Service'
        );
        insight_name = f"{app_name}-redis-insight";
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, insight_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{insight_name}-service",
            namespace,
            'Service'
        );
        delete_if_exists(
            core_v1.delete_namespaced_config_map,
            f"{insight_name}-nginx-config",
            namespace,
            'ConfigMap'
        );
        delete_if_exists(
            core_v1.delete_namespaced_secret,
            f"{insight_name}-auth",
            namespace,
            'Secret'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-mongo-express-sa",
            namespace,
            'ServiceAccount'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service_account,
            f"{app_name}-redis-insight-sa",
            namespace,
            'ServiceAccount'
        );
    }

    def _destroy_component(
        app_name: str, namespace: str, component: str, apps_v1: any, core_v1: any
    ) {
        if component == 'application' {
            self._destroy_application(app_name, namespace, apps_v1, core_v1);
        } elif component == 'database' {
            self._destroy_database(app_name, namespace, apps_v1, core_v1);
        } elif component == 'cache' {
            self._destroy_cache(app_name, namespace, apps_v1, core_v1);
        } elif component == 'monitoring' {
            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.destroy(app_name, namespace, apps_v1, core_v1);
        } elif component == 'dashboard' {
            self._destroy_dashboard(app_name, namespace, apps_v1, core_v1);
        } else {
            raise ValueError(
                f"Unknown component: '{component}'. Valid choices: application, database, cache, monitoring, dashboard"
            );
        }
        if self.logger {
            self.logger.info(f"Component '{component}' of '{app_name}' destroyed");
        }
    }

    def destroy(app_name: str, component: str = "") -> None {
        if self.logger {
            if component {
                self.logger.info(
                    f"Destroying component '{component}' of '{app_name}' from Kubernetes"
                );
            } else {
                self.logger.info(
                    f"Destroying application '{app_name}' from Kubernetes"
                );
            }
        }

        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;

            if component {
                self._destroy_component(
                    app_name, namespace, component, apps_v1, core_v1
                );
                return;
            }

            self._destroy_application(app_name, namespace, apps_v1, core_v1);

            rbac_v1 = client.RbacAuthorizationV1Api();
            networking_v1 = client.NetworkingV1Api();
            ingress_deployer = IngressDeployer(self.k8s_config, self.logger);
            ingress_deployer.destroy(
                app_name, namespace, apps_v1, core_v1, rbac_v1, networking_v1
            );

            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.destroy(app_name, namespace, apps_v1, core_v1);

            self._destroy_databases(app_name, namespace, apps_v1, core_v1);

            pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
            for pvc in pvcs.items {
                if pvc.metadata.name.startswith(app_name) {
                    try {
                        core_v1.delete_namespaced_persistent_volume_claim(
                            name=pvc.metadata.name, namespace=namespace
                        );
                    } except Exception as e {
                        if self.logger {
                            self.logger.warning(
                                f"Failed to delete PVC '{pvc.metadata.name}': {e}"
                            );
                        }
                    }
                }
            }

            if self.logger {
                self.logger.info(
                    f"Waiting for all resources to be deleted for '{app_name}'..."
                );
            }
            self._wait_for_deletion(app_name, namespace, apps_v1, core_v1);

            if namespace != 'default' {
                delete_namespace(namespace);
                if self.logger {
                    self.logger.info(
                        f"Waiting for namespace '{namespace}' to be deleted..."
                    );
                }
                ns_deleted = False;
                ns_elapsed = 0.0;
                ns_max_wait = 120;
                ns_poll = 2.0;
                while ns_elapsed < ns_max_wait {
                    try {
                        core_v1.read_namespace(name=namespace);
                        time.sleep(ns_poll);
                        ns_elapsed = ns_elapsed + ns_poll;
                    } except ApiException as e {
                        if e.status == 404 {
                            ns_deleted = True;
                            break;
                        }
                        raise;
                    }
                }
                if self.logger {
                    if ns_deleted {
                        self.logger.info(f"Namespace '{namespace}' deleted");
                    } else {
                        self.logger.warning(
                            f"Timed out waiting for namespace '{namespace}' to be deleted"
                        );
                    }
                }
            }

            if self.logger {
                self.logger.info(f"Application '{app_name}' destroyed successfully");
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Error destroying application '{app_name}': {e}");
            }
            raise;
        }
    }

    def get_status(app_name: str) -> ResourceStatusInfo {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;

            deployment = apps_v1.read_namespaced_deployment(
                name=app_name, namespace=namespace
            );

            replicas = deployment.spec.replicas or 0;
            ready_replicas = deployment.status.ready_replicas or 0;

            if ready_replicas == replicas and replicas > 0 {
                status = ResourceStatus.RUNNING;
            } elif ready_replicas > 0 {
                status = ResourceStatus.PENDING;
            } else {
                status = ResourceStatus.FAILED;
            }

            return ResourceStatusInfo(
                status=status, replicas=replicas, ready_replicas=ready_replicas
            );
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to get status for '{app_name}': {e}");
            }
            return ResourceStatusInfo(status=ResourceStatus.UNKNOWN, message=str(e));
        }
    }

    def scale(app_name: str, replicas: int) {
        if self.logger {
            self.logger.info(
                f"Scaling application '{app_name}' to {replicas} replicas"
            );
        }

        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            namespace = self.k8s_config.namespace;

            deployment = apps_v1.read_namespaced_deployment(
                name=app_name, namespace=namespace
            );
            deployment.spec.replicas = replicas;

            apps_v1.patch_namespaced_deployment(
                name=app_name, namespace=namespace, body=deployment
            );

            if self.logger {
                self.logger.info(
                    f"Successfully scaled '{app_name}' to {replicas} replicas"
                );
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to scale '{app_name}': {e}");
            }
            raise;
        }
    }

    def _get_lb_endpoint(app_name: str) -> (str | None) {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            namespace = self.k8s_config.namespace;

            if self.k8s_config.shared_ingress {
                networking_v1 = client.NetworkingV1Api();
                ingress = networking_v1.read_namespaced_ingress(
                    name=f"{app_name}-ingress", namespace=namespace
                );
                ing_lb = ingress.status.load_balancer.ingress;
                if ing_lb and len(ing_lb) > 0 {
                    return ing_lb[0].hostname or ing_lb[0].ip;
                }
                return None;
            }
            core_v1 = client.CoreV1Api();
            ingress_svc_name = f"{app_name}-ingress-nginx-service";
            svc = core_v1.read_namespaced_service(
                name=ingress_svc_name, namespace=namespace
            );
            lb_ingress = svc.status.load_balancer.ingress;
            if lb_ingress and len(lb_ingress) > 0 {
                return lb_ingress[0].hostname or lb_ingress[0].ip;
            }
        } except Exception as e {
            if self.logger {
                self.logger.debug(
                    f"Could not get LoadBalancer endpoint for '{app_name}': {e}"
                );
            }
        }
        return None;
    }

    def get_service_url(app_name: str) -> (str | None) {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            namespace = self.k8s_config.namespace;

            if self.k8s_config.domain {
                if self.k8s_config.shared_ingress_tls {
                    return f"https://{self.k8s_config.domain}";
                }
                try {
                    networking_v1 = client.NetworkingV1Api();
                    ingress = networking_v1.read_namespaced_ingress(
                        name=f"{app_name}-ingress", namespace=namespace
                    );
                    if ingress.spec.tls {
                        return f"https://{self.k8s_config.domain}";
                    }
                } except Exception as e {
                    if self.logger {
                        self.logger.debug(f"Could not read ingress TLS status: {e}");
                    }
                }
                return f"http://{self.k8s_config.domain}";
            }

            provider = get_cluster_provider();
            lb_endpoint = self._get_lb_endpoint(app_name)
                if provider.needs_nlb_wait()
                else None;
            url = provider.service_url(lb_endpoint, self.k8s_config.ingress_node_port);
            if url {
                return url;
            }
        } except Exception as e {
            if self.logger {
                self.logger.debug(f"Could not get service URL for '{app_name}': {e}");
            }
        }
        return None;
    }

    def enable_tls(app_name: str) {
        if self.logger {
            self.logger.info(f"Enabling TLS for '{app_name}'...");
        }
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            namespace = self.k8s_config.namespace;
            networking_v1 = client.NetworkingV1Api();
            custom_api = client.CustomObjectsApi();
            core_v1 = client.CoreV1Api();
            apps_v1 = client.AppsV1Api();

            ingress_deployer = IngressDeployer(self.k8s_config, self.logger);
            ingress_deployer.enable_tls(
                app_name, namespace, networking_v1, custom_api, core_v1, apps_v1
            );

            domain = self.k8s_config.domain;
            if not domain {
                try {
                    ingress = networking_v1.read_namespaced_ingress(
                        name=f"{app_name}-ingress", namespace=namespace
                    );
                    ann = ingress.metadata.annotations or {};
                    domain = ann.get('jac-scale/domain', '');
                } except Exception as e {
                    if self.logger {
                        self.logger.debug(f"Could not read ingress annotations: {e}");
                    }
                }
            }

            if domain {
                try {
                    grafana_name = f"{app_name}-grafana";
                    apps_v1.patch_namespaced_deployment(
                        name=grafana_name,
                        namespace=namespace,
                        body={
                            'spec': {
                                'template': {
                                    'spec': {
                                        'containers': [
                                            {
                                                'name': 'grafana',
                                                'env': [
                                                    {
                                                        'name': 'GF_SERVER_ROOT_URL',
                                                        'value': f"https://{domain}/grafana"
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                }
                            }
                        }
                    );
                    if self.logger {
                        self.logger.info(
                            f"Updated Grafana GF_SERVER_ROOT_URL to https://{domain}/grafana"
                        );
                    }
                } except Exception as e {
                    if self.logger {
                        self.logger.debug(f"Could not update Grafana deployment: {e}");
                    }
                }
            }

            if domain and self.logger {
                self.logger.info(f"\nTLS enabled. App is now live at:");
                self.logger.info(f"  App URL:        https://{domain}");
                self.logger.info(f"  Grafana:        https://{domain}/grafana");
                self.logger.info(f"  Mongo Express:  https://{domain}/db-dashboard");
                self.logger.info(f"  RedisInsight:   https://{domain}/cache-dashboard");
                self.logger.info(
                    f"\nCertificate renewal is automatic (cert-manager renews ~30 days before expiry).\n"
                );
            }
            if self.logger {
                self.logger.info(f"TLS successfully enabled for '{app_name}'");
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Failed to enable TLS for '{app_name}': {e}");
            }
            raise;
        }
    }

    def get_full_status(app_name: str) -> dict {
        try {
            try {
                k8s_cluster_config.load_kube_config();
            } except ConfigException {
                k8s_cluster_config.load_incluster_config();
            }
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
        } except Exception as e {
            return {
                'app_name': app_name,
                'namespace': self.k8s_config.namespace,
                'error': str(e),
                'components': [],
                'urls': {}
            };
        }

        namespace = self.k8s_config.namespace;
        components = [];
        urls = {};

        dep_map = {};
        try {
            for d in apps_v1.list_namespaced_deployment(namespace=namespace).items {
                dep_map[d.metadata.name] = d;
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Failed to list Deployments in '{namespace}': {e}"
                );
            }
        }

        sts_map = {};
        try {
            for s in apps_v1.list_namespaced_stateful_set(namespace=namespace).items {
                sts_map[s.metadata.name] = s;
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Failed to list StatefulSets in '{namespace}': {e}"
                );
            }
        }

        restarting_apps = {};
        try {
            for pod in core_v1.list_namespaced_pod(namespace=namespace).items {
                pod_labels = pod.metadata.labels;
                if pod_labels and 'app' in pod_labels {
                    pod_app = pod_labels['app'];
                    if pod.status and pod.status.container_statuses {
                        for cs in pod.status.container_statuses {
                            if cs.restart_count and cs.restart_count > 0 {
                                restarting_apps[pod_app] = True;
                            }
                        }
                    }
                }
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(f"Failed to list Pods in '{namespace}': {e}");
            }
        }

        component_defs = [
            {'k8s_name': app_name + d[0], 'display': d[1], 'is_sts': d[2]}
            for d in COMPANION_DEFS
        ];

        grafana_running = False;
        redis_insight_running = False;
        mongo_express_running = False;
        for cdef in component_defs {
            k8s_name = cdef['k8s_name'];
            display_name = cdef['display'];
            if cdef['is_sts'] {
                resource_map = sts_map;
            } else {
                resource_map = dep_map;
            }
            if k8s_name in resource_map {
                r = resource_map[k8s_name];
                replicas = r.spec.replicas or 0;
                ready = r.status.ready_replicas or 0;
                if ready == replicas and replicas > 0 {
                    status = 'running';
                } elif ready > 0 {
                    status = 'degraded';
                } elif k8s_name in restarting_apps {
                    status = 'restarting';
                } else {
                    status = 'pending';
                }
                components.append(
                    {
                        'name': display_name,
                        'status': status,
                        'ready': ready,
                        'total': replicas
                    }
                );
                if display_name == 'Grafana' {
                    grafana_running = True;
                } elif display_name == 'RedisInsight' {
                    redis_insight_running = True;
                } elif display_name == 'Mongo Express' {
                    mongo_express_running = True;
                }
            } else {
                components.append(
                    {
                        'name': display_name,
                        'status': 'not_deployed',
                        'ready': 0,
                        'total': 0
                    }
                );
            }
        }

        app_url = None;
        try {
            app_url = self.get_service_url(app_name);
            if app_url {
                urls['app'] = app_url;
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Failed to resolve service URL for '{app_name}': {e}"
                );
            }
        }

        base_url = app_url or '';

        if grafana_running {
            urls['grafana'] = f"{base_url}/grafana";
        }

        if redis_insight_running {
            urls['redis_insight'] = f"{base_url}/cache-dashboard";
        }

        if mongo_express_running {
            urls['mongo_express'] = f"{base_url}/db-dashboard";
        }

        return {
            'app_name': app_name,
            'namespace': namespace,
            'components': components,
            'urls': urls
        };
    }
}
