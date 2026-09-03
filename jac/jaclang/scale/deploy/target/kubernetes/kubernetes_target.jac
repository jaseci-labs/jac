import from typing { Any }
import from jaclang.scale.deploy.target.deployment_target { DeploymentTarget }
import from jaclang.scale.models.resource_status { ResourceStatus, ResourceStatusInfo }
import from jaclang.scale.models.progress { EventSink, NoopSink, ProgressEvent }
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    COMPANION_DEFS,
    create_k8s_secret,
    ensure_namespace_exists,
    get_cluster_provider,
    resize_pvc_if_needed
}
import from jaclang.scale.deploy.database.kubernetes_mongo { KubernetesMongoProvider }
import from jaclang.scale.deploy.database.kubernetes_redis { KubernetesRedisProvider }
import from jaclang.scale._optdeps.kubernetes {
    client,
    config as k8s_cluster_config,
    ApiException,
    ConfigException
}
import from jaclang.scale.deploy.database.factory { DatabaseProviderFactory }
import from jaclang.scale.deploy.target.kubernetes.monitoring { MonitoringDeployer }
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }

obj KubernetesTargetBase(DeploymentTarget) {
    has config: KubernetesConfig,
        logger: (Logger | None) = None,
        k8s_config: KubernetesConfig postinit,
        env_list: list = [],
        secrets: dict[str, str] = {},
        env: dict[str, str] = {},
        events: EventSink = NoopSink(),
        dry_run: bool = False;

    def postinit {
        self.k8s_config = self.config;
    }

    def _emit(
        phase: str,
        status: str,
        message: str,
        step: str = "",
        detail: dict[str, any] = {}
    ) {
        self.events.emit(
            ProgressEvent(
                phase=phase, step=step, status=status, message=message, detail=detail
            )
        );
    }

    def _owner_labels -> dict[str, str] {
        return {
            str(k): str(v) for (k, v) in dict(self.k8s_config.labels or {}).items()
        };
    }

    def _load_cluster_config {
        kubeconfig_failed: bool = False;
        try {
            k8s_cluster_config.load_kube_config(
                config_file=(getattr(self.k8s_config, "kubeconfig", "") or None),
                context=(self.k8s_config.kube_context or None)
            );
        } except ConfigException {
            kubeconfig_failed = True;
        }
        if not kubeconfig_failed {
            return;
        }
        try {
            k8s_cluster_config.load_incluster_config();
        } except ConfigException as e {
            raise ConfigException(
                "Could not load Kubernetes config from either kubeconfig "
                "or in-cluster ServiceAccount.\n"
                "If you're deploying from a laptop:\n"
                "  - Start a local cluster:  minikube start\n"
                "  - Verify kubectl works:   kubectl get nodes\n"
                "  - For a remote cluster:   set KUBECONFIG or run "
                "`aws eks update-kubeconfig` / `gcloud container clusters get-credentials`\n"
                "If you're deploying from inside a pod, the pod needs a "
                "ServiceAccount with cluster API access (the default "
                "ServiceAccount usually does, but a restricted one may not).\n"
                f"Original error from in-cluster load: {e}"
            );
        }
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

    def get_status(app_name: str) -> ResourceStatusInfo {
        try {
            self._load_cluster_config();
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
            self._load_cluster_config();
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
            self._load_cluster_config();
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
            self._load_cluster_config();
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
            self._load_cluster_config();
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
            self._load_cluster_config();
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
