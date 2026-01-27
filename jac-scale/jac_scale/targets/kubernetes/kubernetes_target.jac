"""Kubernetes deployment target implementation."""
import os;
import from typing { Any }
import from jac_scale.abstractions.deployment_target { DeploymentTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.abstractions.models.resource_status {
    ResourceStatus,
    ResourceStatusInfo
}
import from jac_scale.abstractions.logger { Logger }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    check_deployment_status,
    cluster_type,
    delete_if_exists,
    check_K8s_status,
    ensure_namespace_exists,
    ensure_pvc_exists,
    load_env_variables,
    validate_resource_limits,
    sync_code_to_pvc
}
import from jac_scale.providers.registry.dockerhub { DockerHubRegistry }
import from jac_scale.providers.database.kubernetes_mongo { KubernetesMongoProvider }
import from jac_scale.providers.database.kubernetes_redis { KubernetesRedisProvider }
import from jac_scale.factories.database_factory { DatabaseProviderFactory }
import from jac_scale.factories.registry_factory { ImageRegistryFactory }
import time;
import from kubernetes { client, config as k8s_config }
import from kubernetes.client.exceptions { ApiException }

"""Kubernetes deployment target implementation."""
class KubernetesTarget(DeploymentTarget) {
    has k8s_config: KubernetesConfig;

    def init(
        self: KubernetesTarget,
        config: KubernetesConfig,
        logger: (Logger | None) = None
    ) -> None {
        self.config = config;
        self.k8s_config = config;
        self.env_list = [];
        if logger {
            self.logger = logger;
        }
    }

    """Get init containers from all enabled database providers."""
    def _get_database_init_containers(
        self: KubernetesTarget, app_name: str
    ) -> list[dict[(str, Any)]] {
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

    """Build resource requests and limits configuration."""
    def _build_resource_config(self: KubernetesTarget) -> dict[(str, Any)] {
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

    """Build readiness and liveness probe configurations."""
    def _build_probe_config(
        self: KubernetesTarget, health_check_path: str
    ) -> dict[(str, Any)] {
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

        return {'readiness': probe_config, 'liveness': liveness_probe};
    }

    """Build Kubernetes service configuration."""
    def _build_service_config(
        self: KubernetesTarget,
        app_name: str,
        is_aws: bool,
        health_check_path: str,
        service_type: str
    ) -> dict[(str, Any)] {
        service_port = 80 if is_aws else self.k8s_config.container_port;
        port_config: dict[(str, Any)] = {
            'protocol': 'TCP',
            'port': service_port,
            'targetPort': self.k8s_config.container_port
        };
        if not is_aws {
            port_config['nodePort'] = self.k8s_config.node_port;
        }

        service_metadata: dict[(str, Any)] = {
            'name': f"{app_name}-service",
            'namespace': self.k8s_config.namespace,
            'labels': {'app': app_name}
        };

        if is_aws {
            service_metadata['annotations'] = {
                'service.beta.kubernetes.io/aws-load-balancer-type': 'nlb',
                'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing',
                'service.beta.kubernetes.io/aws-load-balancer-healthcheck-path': health_check_path
            };
        }

        service = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': service_metadata,
            'spec': {
                'type': service_type,
                'ports': [port_config],
                'selector': {'app': app_name}
            }
        };

        return service;
    }

    """Build the bash command for setting up Jaseci runtime environment."""
    def _build_runtime_setup_command(
        self: KubernetesTarget, app_config: AppConfig
    ) -> list[str] {
        config = self.k8s_config;
        commands = [];

        # Base setup
        commands.append('export DEBIAN_FRONTEND=noninteractive');
        commands.append('apt-get update');

        # Install base packages (curl and unzip needed for Bun installation)
        base_packages = ['git', 'curl', 'unzip'];
        if config.additional_packages {
            base_packages.extend(config.additional_packages);
        }
        commands.append(f"apt-get install -y {' '.join(base_packages)}");

        # Install Bun (required for jac-client frontend builds)
        commands.append('curl -fsSL https://bun.sh/install | bash');
        commands.append('export BUN_INSTALL="$HOME/.bun"');
        commands.append('export PATH="$BUN_INSTALL/bin:$PATH"');

        if app_config.experimental {
            commands.append('rm -rf jaseci');
            clone_cmd = f"git clone --branch {config.jaseci_branch} --single-branch {config.jaseci_repo_url}";
            commands.append(clone_cmd);
            commands.append('cd ./jaseci');
            if config.jaseci_commit {
                commands.append(f"git checkout {config.jaseci_commit}");
            }
            commands.append('git submodule update --init --recursive');
            commands.append('pip install pluggy');
            commands.append('pip install -e ./jac');
            commands.append('pip install -e ./jac-scale');
            commands.append('pip install -e ./jac-client');
            commands.append('pip install -e ./jac-byllm');
            commands.append('cd ..');
        } else {
            packages = config.plugin_versions or {};
            jaclang_v = packages.get('jaclang', 'latest');
            scale_v = packages.get('jac_scale', 'latest');
            client_v = packages.get('jac_client', 'latest');
            byllm_v = packages.get('jac_byllm', 'latest');
            if jaclang_v == 'latest' {
                commands.append('pip install jaclang');
            } else {
                commands.append(f'pip install jaclang=={jaclang_v}');
            }
            if scale_v == 'latest' {
                commands.append('pip install jac-scale');
            } else {
                commands.append(f'pip install jac-scale=={scale_v}');
            }
            if client_v == 'latest' {
                commands.append('pip install jac-client');
            } else {
                commands.append(f'pip install jac-client=={client_v}');
            }
            if byllm_v and byllm_v != 'none' {
                if byllm_v == 'latest' {
                    commands.append('pip install byllm');
                } else {
                    commands.append(f'pip install byllm=={byllm_v}');
                }
            }
        }

        # Change to app directory (project is already copied there via volume mount)
        commands.append(f"cd {config.app_mount_path}");

        # Install Python requirements
        commands.append('jac add');

        # Install Node requirements
        commands.append('jac add --npm');

        # Start the application
        commands.append(f"jac start {app_config.file_name}");

        # Join all commands
        full_command = ' && '.join(commands);

        return ['bash', '-c', full_command];
    }

    """Build container configuration."""
    def _build_container_config(
        self: KubernetesTarget,
        app_name: str,
        image: str,
        probe_configs: dict[(str, Any)],
        resources_config: dict[(str, Any)],
        command: (list[str] | None) = None,
        working_dir: (str | None) = None,
        volume_mounts: (list[dict[(str, Any)]] | None) = None
    ) -> dict[(str, Any)] {
        container_config = {
            'name': app_name,
            'image': image,
            'ports': [{'containerPort': self.k8s_config.container_port}],
            'env': self.env_list,
            'readinessProbe': probe_configs['readiness'],
            'livenessProbe': probe_configs['liveness']
        };

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

    """Build volumes and build container configuration for code sync."""
    def _build_volumes_config(
        self: KubernetesTarget,
        app_name: str,
        app_config: AppConfig,
        namespace: str,
        core_v1: Any
    ) -> dict[str, Any] {
        pvc_name = f"{app_name}-code-pvc";
        pvc_size = self.k8s_config.pvc_size;
        sync_image = self.k8s_config.busybox_image;

        ensure_pvc_exists(core_v1, namespace, pvc_name, pvc_size);
        if self.logger {
            self.logger.info('Syncing application code to PVC');
        }
        sync_code_to_pvc(
            core_v1, namespace, pvc_name, app_config.code_folder, app_name, sync_image
        );

        build_container = {
            'name': 'build-app',
            'image': self.k8s_config.python_image,
            'command': [
                'sh',
                '-c',
                f"apt-get update && apt-get install -y rsync &&  mkdir -p {self.k8s_config.app_mount_path} && rm -rf {self.k8s_config.app_mount_path}/* && rsync -av --exclude='.jac' {self.k8s_config.workspace_path}/ {self.k8s_config.app_mount_path}/"
            ],
            'volumeMounts': [
                {'name': 'app-code', 'mountPath': self.k8s_config.app_mount_path},
                {'name': 'code-source', 'mountPath': self.k8s_config.code_mount_path}
            ]
        };

        volumes = [
            {'name': 'app-code', 'emptyDir': {}},
            {'name': 'code-source', 'persistentVolumeClaim': {'claimName': pvc_name}}
        ];

        return {'volumes': volumes, 'build_container': build_container};
    }

    """Deploy all enabled databases."""
    def _deploy_databases(
        self: KubernetesTarget,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any
    ) -> None {
        if self.k8s_config.mongodb_enabled {
            mongodb_name = f"{app_name}-mongodb";
            mongodb_service_name = f"{mongodb_name}-service";
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            mongo_result = mongo_provider.deploy({});
            self.env_list.append(
                {'name': 'MONGODB_URI', 'value': mongo_result['connection_string']}
            );
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
                    raise ;
                }
            }
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
                    raise ;
                }
            }
        }

        if self.k8s_config.redis_enabled {
            redis_name = f"{app_name}-redis";
            redis_service_name = f"{redis_name}-service";
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', self, {'app_name': app_name}
            );
            redis_result = redis_provider.deploy({});
            self.env_list.append(
                {'name': 'REDIS_URL', 'value': redis_result['connection_string']}
            );
            try {
                apps_v1.read_namespaced_deployment(
                    name=redis_name, namespace=namespace
                );
            } except ApiException as e {
                if (e.status == 404) {
                    apps_v1.create_namespaced_deployment(
                        namespace=namespace, body=redis_result['deployment']
                    );
                } else {
                    raise ;
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
                    raise ;
                }
            }
        }
    }

    """Wait for deployment to be ready and check status."""
    def _wait_for_deployment(
        self: KubernetesTarget,
        app_name: str,
        namespace: str,
        health_check_path: str,
        is_aws: bool
    ) -> None {
        path = health_check_path;
        if is_aws {
            time.sleep(self.k8s_config.aws_nlb_wait);
            nlb_url = None;
            try {
                k8s_config.load_kube_config();
                core_v1 = client.CoreV1Api();
                service_obj = core_v1.read_namespaced_service(
                    f"{app_name}-service", namespace
                );
                nlb_ingress = service_obj.status.load_balancer.ingress;
                if (nlb_ingress and (len(nlb_ingress) > 0)) {
                    endpoint = nlb_ingress[0].hostname or nlb_ingress[0].ip;
                    nlb_url = f"http://{endpoint}";
                } else {
                    if self.logger {
                        self.logger.info(
                            f"NLB is being provisioned. Run 'kubectl get svc {app_name}-service -n {namespace}' to get the endpoint."
                        );
                    }
                }
            } except Exception as e {
                if self.logger {
                    self.logger.warn(f"Could not retrieve NLB endpoint: {e}");
                }
            }
            if (nlb_url) {
                deployment_status = check_deployment_status(
                    self.k8s_config.node_port, path, nlb_url=nlb_url
                );
                if not (deployment_status) {
                    raise Exception("Deployment failed: Application failed to deploy.") ;
                }
                if self.logger {
                    self.logger.info(
                        f"Deployment complete! Access Jaseci-app at {nlb_url}{path}"
                    );
                }
            }
        } else {
            deployment_status = check_deployment_status(
                self.k8s_config.node_port, path
            );
            if deployment_status is False {
                raise Exception("Deployment failed: Application failed to deploy.") ;
            }
            if self.logger {
                self.logger.info(
                    f"Deployment complete! Access Jaseci-app at http://localhost:{self.k8s_config.node_port}{path}"
                );
            }
        }
    }

    """Handle image registry if build is requested."""
    def _handle_image_registry(
        self: KubernetesTarget, app_name: str, app_config: AppConfig
    ) -> str {
        image_name = self.k8s_config.docker_image_name or f"{app_name}:latest";
        repository_name: str;
        if app_config.build and self.image_registry {
            # Build and push image
            full_image = self.image_registry.build_and_push(
                app_config.code_folder, image_name
            );
            repository_name = full_image;
        } elif app_config.build {
            # Create registry if not set
            registry_config = {
                'app_name': app_name,
                'docker_username': self.k8s_config.docker_username,
                'docker_password': self.k8s_config.docker_password,
                'docker_image_name': image_name
            };
            image_registry = ImageRegistryFactory.create('dockerhub', registry_config);
            full_image = image_registry.build_and_push(
                app_config.code_folder, image_name
            );
            repository_name = full_image;
        } else {
            repository_name = self.k8s_config.python_image;
        }
        return repository_name;
    }

    def deploy(self: KubernetesTarget, app_config: AppConfig) -> DeploymentResult {
        # 1. Initialize and validate
        app_name = app_config.app_name or self.k8s_config.app_name;
        namespace = os.getenv('K8s_NAMESPACE') or self.k8s_config.namespace;

        if self.logger {
            self.logger.info(
                f"Deploying application '{app_name}' to Kubernetes",
                {'namespace': namespace, 'build': app_config.build}
            );
        }

        validate_resource_limits(
            self.k8s_config.cpu_request,
            self.k8s_config.cpu_limit,
            self.k8s_config.memory_request,
            self.k8s_config.memory_limit
        );

        # 2. Initialize Kubernetes clients
        k8s_config.load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        check_K8s_status();
        ensure_namespace_exists(namespace);

        # 3. Load environment variables
        self.env_list = load_env_variables(app_config.code_folder);

        # 4. Determine cluster type
        cluster_env = cluster_type();
        is_aws = cluster_env == 'aws';
        service_type = 'LoadBalancer' if is_aws else 'NodePort';

        # 5. Handle image registry if build is requested
        repository_name = self._handle_image_registry(app_name, app_config);

        # 6. Get health check path
        health_check_path = os.getenv(
            'K8s_HEALTHCHECK_PATH', self.k8s_config.health_check_path
        );

        # 7. Get database init containers
        init_containers = self._get_database_init_containers(app_name);

        # 8. Build configurations
        volumes = [];
        resources_config = self._build_resource_config();
        probe_configs = self._build_probe_config(health_check_path);

        # 9. Build container configuration
        container_config = self._build_container_config(
            app_name, repository_name, probe_configs, resources_config
        );

        # 10. Handle volumes and build container if not building image
        if not app_config.build {
            volumes_config = self._build_volumes_config(
                app_name, app_config, namespace, core_v1
            );
            volumes = volumes_config['volumes'];
            build_container = volumes_config['build_container'];
            init_containers.append(build_container);
            # Build runtime setup command
            command = self._build_runtime_setup_command(app_config);
            container_config = self._build_container_config(
                app_name,
                self.k8s_config.python_image,
                probe_configs,
                resources_config,
                command=command,
                working_dir=self.k8s_config.app_mount_path,
                volume_mounts=[
                    {'name': 'app-code', 'mountPath': self.k8s_config.app_mount_path}
                ]
            );
        }

        # 11. Build service and deployment
        service = self._build_service_config(
            app_name, is_aws, health_check_path, service_type
        );
        deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {
                'name': app_name,
                'namespace': namespace,
                'labels': {'app': app_name}
            },
            'spec': {
                'replicas': 1,
                'selector': {'matchLabels': {'app': app_name}},
                'template': {
                    'metadata': {'labels': {'app': app_name}},
                    'spec': {
                        'initContainers': init_containers,
                        'containers': [container_config],
                        'volumes': volumes
                    }
                }
            }
        };

        # 12. Delete existing resources if they exist
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
        );
        time.sleep(self.k8s_config.resource_deletion_wait);

        # 13. Deploy databases
        self._deploy_databases(app_name, namespace, apps_v1, core_v1);

        # 14. Deploy main application
        if self.logger {
            self.logger.info(f'Deploying Jaseci-app app...');
        }
        apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment);
        try {
            core_v1.read_namespaced_service(
                name=f"{app_name}-service", namespace=namespace
            );
        } except ApiException as e {
            if (e.status == 404) {
                core_v1.create_namespaced_service(namespace=namespace, body=service);
            } else {
                raise ;
            }
        }

        # 15. Wait for deployment and get service URL
        self._wait_for_deployment(app_name, namespace, health_check_path, is_aws);
        service_url = self.get_service_url(app_name);

        if self.logger {
            self.logger.info(
                f"Deployment complete for '{app_name}'", {'service_url': service_url}
            );
        }

        return DeploymentResult(
            success=True,
            service_url=service_url,
            message=f"Application '{app_name}' deployed successfully"
        );
    }

    """Destroy all enabled databases."""
    def _destroy_databases(
        self: KubernetesTarget,
        app_name: str,
        namespace: str,
        apps_v1: Any,
        core_v1: Any
    ) -> None {
        if self.k8s_config.mongodb_enabled {
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
        }

        if self.k8s_config.redis_enabled {
            redis_name = f"{app_name}-redis";
            delete_if_exists(
                apps_v1.delete_namespaced_deployment,
                redis_name,
                namespace,
                'Deployment'
            );
            delete_if_exists(
                core_v1.delete_namespaced_service,
                f"{redis_name}-service",
                namespace,
                'Service'
            );
        }
    }

    def destroy(self: KubernetesTarget, app_name: str) -> None {
        if self.logger {
            self.logger.info(f"Destroying application '{app_name}' from Kubernetes");
        }

        try {
            k8s_config.load_kube_config();
            apps_v1 = client.AppsV1Api();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;

            # Delete main deployment and service
            delete_if_exists(
                apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
            );
            delete_if_exists(
                core_v1.delete_namespaced_service,
                f"{app_name}-service",
                namespace,
                'Service'
            );

            # Delete databases
            self._destroy_databases(app_name, namespace, apps_v1, core_v1);

            # Delete code sync pod and PVCs
            delete_if_exists(
                core_v1.delete_namespaced_pod,
                f"{app_name}-code-sync",
                namespace,
                'Pod'
            );

            # Delete PVCs
            pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
            for pvc in pvcs.items {
                if pvc.metadata.name.startswith(app_name) {
                    try {
                        core_v1.delete_namespaced_persistent_volume_claim(
                            name=pvc.metadata.name, namespace=namespace
                        );
                    } except Exception { }
                }
            }

            if self.logger {
                self.logger.info(f"Application '{app_name}' destroyed successfully");
            }
        } except Exception as e {
            if self.logger {
                self.logger.error(f"Error destroying application '{app_name}': {e}");
            }
            raise ;
        }
    }

    def get_status(self: KubernetesTarget, app_name: str) -> ResourceStatusInfo {
        try {
            k8s_config.load_kube_config();
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

    def scale(self: KubernetesTarget, app_name: str, replicas: int) -> None {
        if self.logger {
            self.logger.info(
                f"Scaling application '{app_name}' to {replicas} replicas"
            );
        }

        try {
            k8s_config.load_kube_config();
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
            raise ;
        }
    }

    def get_service_url(self: KubernetesTarget, app_name: str) -> (str | None) {
        try {
            k8s_config.load_kube_config();
            core_v1 = client.CoreV1Api();
            namespace = self.k8s_config.namespace;
            service_name = f"{app_name}-service";

            service = core_v1.read_namespaced_service(
                name=service_name, namespace=namespace
            );

            cluster_env = cluster_type();
            is_aws = cluster_env == 'aws';

            if is_aws {
                # AWS LoadBalancer
                ingress = service.status.load_balancer.ingress;
                if ingress and len(ingress) > 0 {
                    endpoint = ingress[0].hostname or ingress[0].ip;
                    return f"http://{endpoint}";
                }
            } else {
                # NodePort
                node_port = self.k8s_config.node_port;
                return f"http://localhost:{node_port}";
            }
        } except Exception as e {
            if self.logger {
                self.logger.debug(f"Could not get service URL for '{app_name}': {e}");
            }
        }
        return None;
    }
}
