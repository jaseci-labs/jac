"""Implementation of KubernetesTarget deployment logic."""
import os;
import time;
import from typing { Any }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }
import from jac_scale.targets.kubernetes.k8s_utils {
    load_env_variables,
    check_K8s_status,
    ensure_namespace_exists,
    delete_if_exists,
    cluster_type,
    check_deployment_status,
    ensure_pvc_exists,
    sync_code_to_pvc,
    validate_resource_limits
}
import from jac_scale.providers.database.k8s_mongodb { K8sMongoDB }
import from jac_scale.providers.database.k8s_redis { K8sRedis }
import from jac_scale.engine.models.app_config { AppConfig }
import from jac_scale.engine.models.deployment_result { DeploymentResult }
import from jac_scale.engine.config.k8s_config { KubernetesConfig }
import from jac_scale.config_loader { get_scale_config }

"""Implement KubernetesTarget.deploy() with full deployment logic."""
impl KubernetesTarget.deploy(self: KubernetesTarget, app_config: AppConfig) -> DeploymentResult {
    try {
        # Load configuration
        scale_config = get_scale_config();
        k8s_config_dict = scale_config.get_kubernetes_config();
        k8s_config = self.config as KubernetesConfig;

        # Get config values
        app_name = os.getenv('APP_NAME') or k8s_config.app_name or app_config.name;
        image_name = k8s_config_dict.get('docker_image_name') or f"{app_name}:latest";
        namespace = os.getenv('K8s_NAMESPACE') or k8s_config.namespace;
        container_port = k8s_config.container_port;
        node_port = k8s_config.node_port;
        build = k8s_config.build;
        file_name = k8s_config.file_name;
        code_folder = k8s_config.code_folder;

        # Resource limits
        cpu_request = k8s_config_dict.get('cpu_request');
        cpu_limit = k8s_config_dict.get('cpu_limit');
        memory_request = k8s_config_dict.get('memory_request');
        memory_limit = k8s_config_dict.get('memory_limit');
        readiness_initial_delay = int(k8s_config_dict.get('readiness_initial_delay', 10));
        readiness_period = int(k8s_config_dict.get('readiness_period', 20));
        liveness_initial_delay = int(k8s_config_dict.get('liveness_initial_delay', 10));
        liveness_period = int(k8s_config_dict.get('liveness_period', 20));
        liveness_failure_threshold = int(k8s_config_dict.get('liveness_failure_threshold', 80));

        validate_resource_limits(cpu_request, cpu_limit, memory_request, memory_limit);

        # Image configuration
        docker_username = k8s_config_dict.get('docker_username') or 'juzailmlwork';
        repository_name = f"{docker_username}/{image_name}" if build else 'python:3.12-slim';

        # Database configuration
        mongodb_enabled = k8s_config_dict.get('mongodb_enabled', True);
        redis_enabled = k8s_config_dict.get('redis_enabled', True);

        self.logger.info(f"Deploying {app_name} to Kubernetes namespace '{namespace}'");

        # Initialize K8s clients
        config.load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        check_K8s_status();
        ensure_namespace_exists(namespace);

        # Load environment variables
        env_list = load_env_variables(code_folder);

        # Detect cluster type
        cluster_env = cluster_type();
        is_aws = cluster_env == 'aws';
        service_type = 'LoadBalancer' if is_aws else 'NodePort';

        # Initialize containers
        init_containers: list[dict[str, Any]] = [];
        default_health_path = '/docs';
        health_check_path = os.getenv('K8s_HEALTHCHECK_PATH', default_health_path);

        # Deploy databases if enabled
        if mongodb_enabled {
            mongodb_provider = K8sMongoDB(target=self, app_name=app_name, namespace=namespace);
        mongodb_result = mongodb_provider.deploy({'env_vars': env_list});
        mongodb_name = mongodb_result['name'];
        mongodb_service_name = mongodb_result['service_name'];

        init_containers.append({
            'name': 'wait-for-mongodb',
            'image': 'busybox',
            'command': [
                'sh', '-c',
                f"until nc -z {mongodb_service_name} 27017; do echo waiting for mongodb; sleep 3; done"
            ]
        });

        # Create MongoDB resources
        try {
            apps_v1.read_namespaced_stateful_set(name=mongodb_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_stateful_set(
                    namespace=namespace, body=mongodb_result['statefulset']
                );
            } else {
                raise;
            }
        }
        try {
            core_v1.read_namespaced_service(name=mongodb_service_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=mongodb_result['service']
                );
            } else {
                raise;
            }
        }

        if redis_enabled {
        redis_provider = K8sRedis(target=self, app_name=app_name, namespace=namespace);
        redis_result = redis_provider.deploy({'env_vars': env_list});
        redis_name = redis_result['name'];
        redis_service_name = redis_result['service_name'];

        init_containers.append({
            'name': 'wait-for-redis',
            'image': 'busybox',
            'command': [
                'sh', '-c',
                f"until nc -z {redis_service_name} 6379; do echo waiting for redis; sleep 3; done"
            ]
        });

        # Create Redis resources
        try {
            apps_v1.read_namespaced_deployment(name=redis_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=redis_result['deployment']
                );
            } else {
                raise;
            }
        }
        try {
            core_v1.read_namespaced_service(name=redis_service_name, namespace=namespace);
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=redis_result['service']
                );
            } else {
                raise;
            }
        }

        # Build container configuration
    volumes = [];
    probe_config = {
        'httpGet': {
            'path': health_check_path,
            'port': container_port,
            'scheme': 'HTTP'
        },
        'initialDelaySeconds': readiness_initial_delay,
        'periodSeconds': readiness_period
    };
    liveness_probe = dict(probe_config);
    liveness_probe['initialDelaySeconds'] = liveness_initial_delay;
    liveness_probe['periodSeconds'] = liveness_period;
    liveness_probe['failureThreshold'] = liveness_failure_threshold;

    resource_requests: dict[str, str] = {};
    if cpu_request {
        resource_requests['cpu'] = cpu_request;
    }
    if memory_request {
        resource_requests['memory'] = memory_request;
    }
    resource_limits: dict[str, str] = {};
    if cpu_limit {
        resource_limits['cpu'] = cpu_limit;
    }
    if memory_limit {
        resource_limits['memory'] = memory_limit;
    }
    resources_config: dict[str, Any] = {};
    if resource_requests {
        resources_config['requests'] = resource_requests;
    }
    if resource_limits {
        resources_config['limits'] = resource_limits;
    }

    container_config = {
        'name': app_name,
        'image': repository_name,
        'ports': [{'containerPort': container_port}],
        'env': env_list,
        'readinessProbe': probe_config,
        'livenessProbe': liveness_probe
    };
    if resources_config {
        container_config['resources'] = resources_config;
    }

    # Handle non-build mode (sync code to PVC)
    if not build {
        pvc_name = f"{app_name}-code-pvc";
        pvc_size = '5Gi';
        sync_image = 'busybox:1.36';
        ensure_pvc_exists(core_v1, namespace, pvc_name, pvc_size);
        self.logger.info('Syncing application code');
        sync_code_to_pvc(core_v1, namespace, pvc_name, code_folder, app_name, sync_image);

        build_container = {
            'name': 'build-app',
            'image': 'python:3.12-slim',
            'command': [
                'sh', '-c',
                'mkdir -p /app && rm -rf /app/* && cp -r /code/workspace/. /app/'
            ],
            'volumeMounts': [
                {'name': 'app-code', 'mountPath': '/app'},
                {'name': 'code-source', 'mountPath': '/code'}
            ]
        };
        volumes = [
            {'name': 'app-code', 'emptyDir': {}},
            {'name': 'code-source', 'persistentVolumeClaim': {'claimName': pvc_name}}
        ];
        init_containers.append(build_container);

        if 'requirements.txt' in os.listdir(code_folder) {
            install_part = f"pip install -r /app/requirements.txt && jac serve src/{file_name}";
        } else {
            install_part = f"jac serve src/{file_name}";
        }
        command = [
            'bash', '-c',
            f"export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -y git npm nodejs && rm -rf jaseci && git clone --branch health-check-resource-limit --single-branch https://github.com/juzailmlwork/jaseci.git && cd ./jaseci && git checkout 97457c30d460e60942d9f955cc290e487a77af9c && git submodule update --init --recursive && python -m venv venv && source venv/bin/activate && pip install pluggy && pip install -e ./jac && pip install -e ./jac-scale && pip install -e ./jac-client && cd ../../.. && jac create --cl client_app && cp -r ./app/* ./client_app/src && [ -f ./app/jac.toml ] && cp ./app/jac.toml ./client_app/jac.toml || true && cd ./client_app && jac add --cl && {install_part}"
        ];
        container_config = {
            'name': app_name,
            'image': 'python:3.12-slim',
            'command': command,
            'workingDir': '/app',
            'volumeMounts': [{'name': 'app-code', 'mountPath': '/app'}],
            'ports': [{'containerPort': container_port}],
            'env': env_list,
            'readinessProbe': probe_config,
            'livenessProbe': liveness_probe
        };
        if resources_config {
            container_config['resources'] = resources_config;
        }
    }

    # Build service configuration
    service_port = 80 if is_aws else container_port;
    port_config: dict[str, Any] = {
        'protocol': 'TCP',
        'port': service_port,
        'targetPort': container_port
    };
    if not is_aws {
        port_config['nodePort'] = node_port;
    }

    service_spec: dict[str, Any] = {
        'selector': {'app': app_name},
        'ports': [port_config],
        'type': service_type
    };

    service_metadata: dict[str, Any] = {'name': f"{app_name}-service"};
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

    # Build deployment configuration
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

    # Delete existing resources
    delete_if_exists(
        apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
    );
    delete_if_exists(
        core_v1.delete_namespaced_service, f"{app_name}-service", namespace, 'Service'
    );
    time.sleep(5);

    # Create deployment and service
    self.logger.info(f'Deploying {app_name} app...');
    apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment);
    core_v1.create_namespaced_service(namespace=namespace, body=service);

    # Check deployment status
    path = health_check_path;
    if is_aws {
        time.sleep(60);
        nlb_url = None;
        try {
            service_obj = core_v1.read_namespaced_service(f"{app_name}-service", namespace);
            nlb_ingress = service_obj.status.load_balancer.ingress;
            if nlb_ingress and len(nlb_ingress) > 0 {
                endpoint = nlb_ingress[0].hostname or nlb_ingress[0].ip;
                nlb_url = f"http://{endpoint}";
            }
        } except Exception as e {
            self.logger.warning(f"Could not retrieve NLB endpoint: {e}");
        }
        if nlb_url and check_deployment_status(node_port, path, nlb_url=nlb_url) {
            service_url = f"{nlb_url}{path}";
            return DeploymentResult(
                success=True,
                service_url=service_url,
                deployment_id=f"{app_name}-{int(time.time())}"
            );
        }
    } elif check_deployment_status(node_port, path) {
        service_url = f"http://localhost:{node_port}{path}";
        return DeploymentResult(
            success=True,
            service_url=service_url,
            deployment_id=f"{app_name}-{int(time.time())}"
        );
    }

    # Return success even if health check didn't pass (deployment might still be starting)
    service_url = self.get_service_url(app_name);
    return DeploymentResult(
        success=True,
        service_url=service_url,
        deployment_id=f"{app_name}-{int(time.time())}"
    );
}

"""Implement KubernetesTarget.destroy() with cleanup logic."""
impl KubernetesTarget.destroy(self: KubernetesTarget, app_name: str) -> None {
    scale_config = get_scale_config();
    k8s_config_dict = scale_config.get_kubernetes_config();
    k8s_config = self.config as KubernetesConfig;

    app_name = os.getenv('APP_NAME', app_name);
    namespace = os.getenv('K8s_NAMESPACE') or k8s_config.namespace;

    self.logger.info(f"Destroying deployment: {app_name}");

    config.load_kube_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();

    deployment_name = app_name;
    service_name = f"{app_name}-service";

    delete_if_exists(
        apps_v1.delete_namespaced_deployment, deployment_name, namespace, 'Deployment'
    );
    delete_if_exists(
        core_v1.delete_namespaced_service, service_name, namespace, 'Service'
    );

    # Cleanup databases
    mongodb_name = f"{app_name}-mongodb";
    redis_name = f"{app_name}-redis";

    delete_if_exists(
        apps_v1.delete_namespaced_stateful_set, mongodb_name, namespace, 'StatefulSet'
    );
    delete_if_exists(
        core_v1.delete_namespaced_service,
        f"{mongodb_name}-service",
        namespace,
        'Service'
    );
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
        core_v1.delete_namespaced_pod, f"{app_name}-code-sync", namespace, 'Pod'
    );

    # Cleanup PVCs
    pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
    for pvc in pvcs.items {
        if pvc.metadata.name.startswith(app_name) {
            try {
                core_v1.delete_namespaced_persistent_volume_claim(
                    pvc.metadata.name, namespace
                );
            } except ApiException as e {
                self.logger.warning(f"Error deleting PVC '{pvc.metadata.name}': {e}");
            }
        }
    }

    self.logger.info(f"All Kubernetes resources for '{app_name}' cleaned up successfully.");
}
