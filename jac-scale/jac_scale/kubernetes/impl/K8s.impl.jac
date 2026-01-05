"""Deploy jac application to K8s."""

impl deploy_K8s(
    code_folder: str,
    file_name: str = 'none',
    build: bool = False,
    testing: bool = False
) -> None {
    cpu_request = _k8s_config.get('cpu_request');
    cpu_limit = _k8s_config.get('cpu_limit');
    memory_request = _k8s_config.get('memory_request');
    memory_limit = _k8s_config.get('memory_limit');
    readiness_initial_delay = int(_k8s_config.get('readiness_initial_delay', 10));
    readiness_period = int(_k8s_config.get('readiness_period', 20));
    liveness_initial_delay = int(_k8s_config.get('liveness_initial_delay', 10));
    liveness_period = int(_k8s_config.get('liveness_period', 20));
    liveness_failure_threshold = int(_k8s_config.get('liveness_failure_threshold', 80));
    validate_resource_limits(cpu_request, cpu_limit, memory_request, memory_limit);
    # Use configuration from jac.toml with env var overrides
    app_name = os.getenv('APP_NAME') or _k8s_config['app_name'];
    image_name = _k8s_config['docker_image_name'] or f"{app_name}:latest";
    namespace = os.getenv('K8s_NAMESPACE') or _k8s_config['namespace'];
    container_port = _k8s_config['container_port'];
    node_port = _k8s_config['node_port'];
    docker_username = _k8s_config['docker_username'] or 'juzailmlwork';
    repository_name = f"{docker_username}/{image_name}";
    mongodb_enabled = _k8s_config['mongodb_enabled'];
    redis_enabled = _k8s_config['redis_enabled'];
    if not build {
        repository_name = 'python:3.12-slim';
    }
    # print(f"Deploying Jaseci-app '{app_name}' to Kubernetes namespace '{namespace}'");
    config.load_kube_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();
    check_K8s_status();
    ensure_namespace_exists(namespace);
    env_list = load_env_variables(code_folder);
    cluster_env = cluster_type();
    is_aws = cluster_env == 'aws';
    service_type = 'LoadBalancer' if is_aws else 'NodePort';
    init_containers: list[dict[(str, Any)]] = [];
    default_health_path = '/docs';
    health_check_path = os.getenv('K8s_HEALTHCHECK_PATH', default_health_path);
    if mongodb_enabled {
        mongodb_name = f"{app_name}-mongodb";
        mongodb_service_name = f"{mongodb_name}-service";
        (mongodb_deployment, mongodb_service) = mongo_db(app_name, env_list);
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
    if redis_enabled {
        redis_name = f"{app_name}-redis";
        redis_service_name = f"{redis_name}-service";
        (redis_deployment, redis_service) = redis_db(app_name, env_list);
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
    resource_requests: dict[(str, str)] = {};
    if cpu_request {
        resource_requests['cpu'] = cpu_request;
    }
    if memory_request {
        resource_requests['memory'] = memory_request;
    }
    resource_limits: dict[(str, str)] = {};
    if cpu_limit {
        resource_limits['cpu'] = cpu_limit;
    }
    if memory_limit {
        resource_limits['memory'] = memory_limit;
    }
    resources_config: dict[(str, Any)] = {};
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
    if not build {
        pvc_name = f"{app_name}-code-pvc";
        pvc_size = '5Gi';
        sync_image = 'busybox:1.36';
        ensure_pvc_exists(core_v1, namespace, pvc_name, pvc_size);
        print('Syncing application code');
        sync_code_to_pvc(
            core_v1, namespace, pvc_name, code_folder, app_name, sync_image
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
            {'name': 'code-source', 'persistentVolumeClaim': {'claimName': pvc_name}}
        ];
        init_containers.append(build_container);
        if ('requirements.txt' in os.listdir(code_folder)) {
            install_part = f"pip install -r /app/requirements.txt && jac serve src/{file_name}";
        } else {
            install_part = f"jac serve src/{file_name} ";
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
            'ports': [{'containerPort': container_port}],
            'env': env_list,
            'readinessProbe': probe_config,
            'livenessProbe': liveness_probe
        };
        if resources_config {
            container_config['resources'] = resources_config;
        }
    }
    service_port = 80 if is_aws else container_port;
    port_config: dict[(str, Any)] = {
        'protocol': 'TCP',
        'port': service_port,
        'targetPort': container_port
    };
    if not is_aws {
        port_config['nodePort'] = node_port;
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
    delete_if_exists(
        apps_v1.delete_namespaced_deployment, app_name, namespace, 'Deployment'
    );
    delete_if_exists(
        core_v1.delete_namespaced_service, f"{app_name}-service", namespace, 'Service'
    );
    time.sleep(5);
    if mongodb_enabled {
        try {
            apps_v1.read_namespaced_stateful_set(
                name=mongodb_name, namespace=namespace
            );
        } except ApiException as e {
            if (e.status == 404) {
                apps_v1.create_namespaced_stateful_set(
                    namespace=namespace, body=mongodb_deployment
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
                    namespace=namespace, body=mongodb_service
                );
            } else {
                raise ;
            }
        }
    }
    if redis_enabled {
        try {
            apps_v1.read_namespaced_deployment(name=redis_name, namespace=namespace);
        } except ApiException as e {
            if (e.status == 404) {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=redis_deployment
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
                    namespace=namespace, body=redis_service
                );
            } else {
                raise ;
            }
        }
    }
    print('Deploying Jaseci-app app...');
    apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment);
    core_v1.create_namespaced_service(namespace=namespace, body=service);
    path = health_check_path;
    if is_aws {
        time.sleep(60);
        nlb_url = None;
        try {
            service = core_v1.read_namespaced_service(f"{app_name}-service", namespace);
            nlb_ingress = service.status.load_balancer.ingress;
            if (nlb_ingress and (len(nlb_ingress) > 0)) {
                endpoint = nlb_ingress[0].hostname or nlb_ingress[0].ip;
                nlb_url = f"http://{endpoint}";
            } else {
                print(
                    f"NLB is being provisioned. Run 'kubectl get svc {app_name}-service -n {namespace}' to get the endpoint."
                );
            }
        } except Exception as e {
            print(f"Could not retrieve NLB endpoint: {e}");
            print(
                f"Run 'kubectl get svc {app_name}-service -n {namespace}' to get the NLB endpoint."
            );
        }
        if (nlb_url and check_deployment_status(node_port, path, nlb_url=nlb_url)) {
            print(f"Deployment complete! Access Jaseci-app at {nlb_url}{path}");
        }
    } elif check_deployment_status(node_port, path) {
        print(
            f"Deployment complete! Access Jaseci-app at http://localhost:{node_port}{path}"
        );
    }
}
