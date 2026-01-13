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
        if logger {
            self.logger = logger;
        }
    }

    def deploy(self: KubernetesTarget, app_config: AppConfig) -> DeploymentResult {
        # Use app_name from app_config if provided, otherwise use config
        app_name = app_config.app_name or self.k8s_config.app_name;
        namespace = os.getenv('K8s_NAMESPACE') or self.k8s_config.namespace;

        # Log deployment start
        if self.logger {
            self.logger.info(
                f"Deploying application '{app_name}' to Kubernetes",
                {'namespace': namespace, 'build': app_config.build}
            );
        }

        # Validate resource limits
        validate_resource_limits(
            self.k8s_config.cpu_request,
            self.k8s_config.cpu_limit,
            self.k8s_config.memory_request,
            self.k8s_config.memory_limit
        );

        # Load kube config and initialize clients
        k8s_config.load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        check_K8s_status();
        ensure_namespace_exists(namespace);

        # Load environment variables
        env_list = load_env_variables(app_config.code_folder);

        # Determine cluster type and service configuration
        cluster_env = cluster_type();
        is_aws = cluster_env == 'aws';
        service_type = 'LoadBalancer' if is_aws else 'NodePort';

        # Handle image registry if build is requested
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
            repository_name = 'python:3.12-slim';
        }

        # Setup init containers and database providers
        init_containers: list[dict[(str, Any)]] = [];
        health_check_path = os.getenv(
            'K8s_HEALTHCHECK_PATH', self.k8s_config.health_check_path
        );

        # Setup MongoDB if enabled
        if self.k8s_config.mongodb_enabled {
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            mongo_result = mongo_provider.deploy({});
            init_containers.append(
                {
                    'name': 'wait-for-mongodb',
                    'image': 'busybox',
                    'command': [
                        'sh',
                        '-c',
                        f"until nc -z {app_name}-mongodb-service 27017; do echo waiting for mongodb; sleep 3; done"
                    ]
                }
            );
        }

        # Setup Redis if enabled
        if self.k8s_config.redis_enabled {
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', self, {'app_name': app_name}
            );
            redis_result = redis_provider.deploy({});
            init_containers.append(
                {
                    'name': 'wait-for-redis',
                    'image': 'busybox',
                    'command': [
                        'sh',
                        '-c',
                        f"until nc -z {app_name}-redis-service 6379; do echo waiting for redis; sleep 3; done"
                    ]
                }
            );
        }

        # Build container configuration
        volumes = [];
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

        # Resource configuration
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
        resources_config: dict[(str, Any)] = {};
        if resource_requests {
            resources_config['requests'] = resource_requests;
        }
        if resource_limits {
            resources_config['limits'] = resource_limits;
        }

        # Container configuration
        container_config = {
            'name': app_name,
            'image': repository_name,
            'ports': [{'containerPort': self.k8s_config.container_port}],
            'env': env_list,
            'readinessProbe': probe_config,
            'livenessProbe': liveness_probe
        };
        if resources_config {
            container_config['resources'] = resources_config;
        }

        # Handle non-build deployment (code sync via PVC)
        if not app_config.build {
            pvc_name = f"{app_name}-code-pvc";
            pvc_size = '5Gi';
            sync_image = 'busybox:1.36';
            ensure_pvc_exists(core_v1, namespace, pvc_name, pvc_size);
            if self.logger {
                self.logger.info('Syncing application code to PVC');
            }
            sync_code_to_pvc(
                core_v1,
                namespace,
                pvc_name,
                app_config.code_folder,
                app_name,
                sync_image
            );
            build_container = {
                'name': 'build-app',
                'image': 'python:3.12-slim',
                'command': [
                    'sh',
                    '-c',
                    'mkdir -p /app && rm -rf /app/* && cp -r /code/workspace/. /app/'
                ],
                'volumeMounts': [
                    {'name': 'app-code', 'mountPath': '/app'},
                    {'name': 'code-source', 'mountPath': '/code'}
                ]
            };
            volumes = [
                {'name': 'app-code', 'emptyDir': {}},
                {
                    'name': 'code-source',
                    'persistentVolumeClaim': {'claimName': pvc_name}
                }
            ];
            init_containers.append(build_container);
            if ('requirements.txt' in os.listdir(app_config.code_folder)) {
                install_part = f"pip install -r /app/requirements.txt && jac start src/{app_config.file_name}";
            } else {
                install_part = f"jac start src/{app_config.file_name} ";
            }
            command = [
                'bash',
                '-c',
                f"export DEBIAN_FRONTEND=noninteractive &&apt-get update &&apt-get install -y git npm nodejs && rm -rf jaseci && git clone --branch health-check-resource-limit --single-branch https://github.com/juzailmlwork/jaseci.git &&cd ./jaseci &&git checkout 97457c30d460e60942d9f955cc290e487a77af9c &&git submodule update --init --recursive &&python -m venv venv &&source venv/bin/activate &&pip install pluggy &&pip install -e ./jac &&pip install -e  ./jac-scale &&pip install -e ./jac-client &&cd ../../.. &&jac create --cl client_app &&cp -r ./app/* ./client_app/src && [ -f ./app/jac.toml ] && cp ./app/jac.toml ./client_app/jac.toml || true &&cd ./client_app  && jac add --cl &&{install_part}"
            ];
            container_config = {
                'name': app_name,
                'image': 'python:3.12-slim',
                'command': command,
                'workingDir': '/app',
                'volumeMounts': [{'name': 'app-code', 'mountPath': '/app'}],
                'ports': [{'containerPort': self.k8s_config.container_port}],
                'env': env_list,
                'readinessProbe': probe_config,
                'livenessProbe': liveness_probe
            };
            if resources_config {
                container_config['resources'] = resources_config;
            }
        }

        # Service configuration
        service_port = 80 if is_aws else self.k8s_config.container_port;
        port_config: dict[(str, Any)] = {
            'protocol': 'TCP',
            'port': service_port,
            'targetPort': self.k8s_config.container_port
        };
        if not is_aws {
            port_config['nodePort'] = self.k8s_config.node_port;
        }
        service_spec: dict[(str, Any)] = {
            'selector': {'app': app_name},
            'ports': [port_config],
            'type': service_type
        };
        service_metadata: dict[(str, Any)] = {'name': f"{app_name}-service"};
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
            'spec': service_spec
        };

        # Deployment configuration
        deployment = {
            'apiVersion': 'apps/v1',
            'kind': 'Deployment',
            'metadata': {'name': app_name, 'labels': {'app': app_name}},
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

        # Delete existing resources if they exist
        delete_if_exists(
            apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
        );
        delete_if_exists(
            core_v1.delete_namespaced_service,
            f"{app_name}-service",
            namespace,
            'Service'
        );
        time.sleep(5);

        # Deploy databases if enabled
        if self.k8s_config.mongodb_enabled {
            mongodb_name = f"{app_name}-mongodb";
            mongodb_service_name = f"{mongodb_name}-service";
            mongo_provider = DatabaseProviderFactory.create(
                'kubernetes_mongo', self, {'app_name': app_name}
            );
            mongo_result = mongo_provider.deploy({});
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

        # Deploy main application
        if self.logger {
            self.logger.info(f'Deploying Jaseci-app app...');
        }
        apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment);
        core_v1.create_namespaced_service(namespace=namespace, body=service);

        # Wait and check deployment status
        path = health_check_path;
        if is_aws {
            time.sleep(60);
            nlb_url = None;
            try {
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
            if (
                nlb_url
                and check_deployment_status(
                    self.k8s_config.node_port, path, nlb_url=nlb_url
                )
            ) {
                if self.logger {
                    self.logger.info(
                        f"Deployment complete! Access Jaseci-app at {nlb_url}{path}"
                    );
                }
            }
        } elif check_deployment_status(self.k8s_config.node_port, path) {
            if self.logger {
                self.logger.info(
                    f"Deployment complete! Access Jaseci-app at http://localhost:{self.k8s_config.node_port}{path}"
                );
            }
        }

        # Get service URL
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

            # Delete MongoDB if enabled
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

            # Delete Redis if enabled
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
                    } except Exception {
                        pass;
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
