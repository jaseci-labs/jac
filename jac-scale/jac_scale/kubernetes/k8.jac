"""File covering k8 automation."""
import os;
import time;
import from typing { Any }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }
import from .database.mongo { mongo_db }
import from .database.redis { redis_db }
import from .utils {
    check_deployment_status,
    check_k8_status,
    cluster_type,
    delete_if_exists,
    ensure_namespace_exists,
    ensure_pvc_exists,
    load_env_variables,
    sync_code_to_pvc
}

"""Deploy jac application to k8."""
def deploy_k8(
    code_folder: str,
    file_name: str = 'none',
    build: bool = False,
    testing: bool = False
) -> None {
    app_name = os.getenv('APP_NAME', 'jaseci');
    image_name = os.getenv('DOCKER_IMAGE_NAME', f"{app_name}:latest");
    namespace = os.getenv('K8_NAMESPACE', 'default');
    container_port = int(os.getenv('K8_CONTAINER_PORT', '8000'));
    node_port = int(os.getenv('K8_NODE_PORT', '30001'));
    docker_username = os.getenv('DOCKER_USERNAME', 'juzailmlwork');
    repository_name = f"{docker_username}/{image_name}";
    mongodb_enabled = os.getenv('K8_MONGODB', 'true').lower() == 'true';
    redis_enabled = os.getenv('K8_REDIS', 'true').lower() == 'true';
    if not build {
        repository_name = 'python:3.12-slim';
    }
    config.load_kube_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();
    check_k8_status();
    ensure_namespace_exists(namespace);
    env_list = load_env_variables(code_folder);
    cluster_env = cluster_type();
    is_aws = cluster_env == 'aws';
    service_type = 'LoadBalancer' if is_aws else 'NodePort';
    init_containers: list[dict[(str, Any)]] = [];
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
    container_config = {
        'name': app_name,
        'image': repository_name,
        'ports': [{'containerPort': container_port}],
        'env': env_list
    };
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
            install_part = f"pip install -r /app/requirements.txt && jac serve {file_name}";
        } else {
            install_part = f"jac serve {file_name} ";
        }
        command = [
            'bash',
            '-c',
            f"export DEBIAN_FRONTEND=noninteractive &&apt-get update &&apt-get install -y git npm nodejs &&git clone --branch jac_scale_examples --single-branch --depth 1 https://github.com/mgtm98/jaseci.git &&cd ./jaseci &&git submodule update --init --recursive &&python -m venv venv &&source venv/bin/activate &&pip install pluggy &&pip install -e ./jac &&pip install -e  ./jac-scale &&pip install jac-client &&jac -V &&cd ../../.. &&jac create_jac_app client_app &&cp -r ./app/* ./client_app &&cd ./client_app &&{install_part}"
        ];
        container_config = {
            'name': app_name,
            'image': 'python:3.12-slim',
            'command': command,
            'workingDir': '/app',
            'volumeMounts': [{'name': 'app-code', 'mountPath': '/app'}],
            'ports': [{'containerPort': container_port}],
            'env': env_list
        };
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
            'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing'
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
    path = '/walkers' if testing else '/docs';
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
