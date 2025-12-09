"""File covering k8 automation."""
import os;
import shutil;
import subprocess;
import tempfile;
import time;
import from pathlib { Path }
import from typing { Any }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }
import from .database.mongo { mongo_db }
import from .database.redis { redis_db }
import from .utils {
    check_deployment_status,
    check_k8_status,
    create_tarball,
    delete_if_exists,
    ensure_namespace_exists,
    load_env_variables
}

"""Create a PersistentVolumeClaim if it does not already exist."""
def ensure_pvc_exists(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    storage_size: str,
    storage_class: (str | None) = None,
    access_mode: str = 'ReadWriteOnce'
) -> None {
    try {
        core_v1.read_namespaced_persistent_volume_claim(pvc_name, namespace);
        return;
    } except ApiException as exc {
        if (exc.status != 404) {
            raise ;
        }
    }
    pvc_body: dict[(str, Any)] = {
        'apiVersion': 'v1',
        'kind': 'PersistentVolumeClaim',
        'metadata': {'name': pvc_name},
        'spec': {
            'accessModes': [access_mode],
            'resources': {'requests': {'storage': storage_size}}
        }
    };
    if storage_class {
        pvc_body['spec']['storageClassName'] = storage_class;
    }
    core_v1.create_namespaced_persistent_volume_claim(namespace, pvc_body);
}

"""Poll the pod until it reaches one of the desired phases."""
def wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None {
    start_time = time.time();
    while ((time.time() - start_time) < timeout) {
        try {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                time.sleep(2);
                continue;
            }
            raise ;
        }
        phase = (pod.status.phase or '').strip();
        if (phase in target_phases) {
            return;
        }
        if (phase == 'Failed') {
            raise RuntimeError(f"Sync pod '{pod_name}' entered Failed state.") ;
        }
        time.sleep(2);
    }
    raise TimeoutError(
        f"Timed out while waiting for pod '{pod_name}' to reach phase {target_phases}."
    ) ;
}

"""Block until the pod disappears from the API."""
def wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None {
    start_time = time.time();
    while ((time.time() - start_time) < timeout) {
        try {
            core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                return;
            }
            raise ;
        }
        time.sleep(2);
    }
    raise TimeoutError(f"Timed out waiting for pod '{pod_name}' deletion.") ;
}

"""Execute a kubectl command and surface useful error details."""
def run_kubectl_command(args: list[str], cwd: (Path | None) = None) -> None {
    if (shutil.which('kubectl') is None) {
        raise RuntimeError('kubectl is required to sync code to the PVC.') ;
    }
    try {
        subprocess.run(
            ['kubectl', *args], check=True, text=True, cwd=str(cwd) if cwd else None
        );
    } except subprocess.CalledProcessError as exc {
        raise exc from RuntimeError(
            f"kubectl command failed: {' '.join(['kubectl', *args])}"
        ) ;
    }
}

"""Stage the application code inside the PVC using a transient helper pod."""
def sync_code_to_pvc(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    code_folder: str,
    app_name: str,
    sync_image: str
) -> None {
    sync_pod_name = f"{app_name}-code-sync";
    pod_body = {
        'apiVersion': 'v1',
        'kind': 'Pod',
        'metadata': {'name': sync_pod_name},
        'spec': {
            'restartPolicy': 'Never',
            'containers': [
                {
                    'name': 'sync',
                    'image': sync_image,
                    'command': ['sh', '-c', 'sleep 3600'],
                    'volumeMounts': [{'name': 'code', 'mountPath': '/data'}]
                }
            ],
            'volumes': [
                {'name': 'code', 'persistentVolumeClaim': {'claimName': pvc_name}}
            ]
        }
    };
    try {
        core_v1.create_namespaced_pod(namespace, pod_body);
    } except ApiException as exc {
        if (exc.status == 409) {
            core_v1.delete_namespaced_pod(sync_pod_name, namespace);
            wait_for_pod_deletion(core_v1, namespace, sync_pod_name);
            core_v1.create_namespaced_pod(namespace, pod_body);
        } else {
            raise ;
        }
    }
    wait_for_pod_phase(core_v1, namespace, sync_pod_name, {'Running'});
    with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as temp_tar {
        temp_tar_path = Path(temp_tar.name);
    }
    try {
        create_tarball(code_folder, str(temp_tar_path));
        run_kubectl_command(
            [
                'exec',
                '-n',
                namespace,
                sync_pod_name,
                '--',
                'sh',
                '-c',
                'rm -rf /data/* && mkdir -p /data/workspace'
            ]
        );
        run_kubectl_command(
            [
                'cp',
                '-n',
                namespace,
                temp_tar_path.name,
                f"{sync_pod_name}:/tmp/jaseci-code.tar.gz"
            ],
            cwd=temp_tar_path.parent
        );
        run_kubectl_command(
            [
                'exec',
                '-n',
                namespace,
                sync_pod_name,
                '--',
                'sh',
                '-c',
                'tar -xzf /tmp/jaseci-code.tar.gz -C /data/workspace && rm -f /tmp/jaseci-code.tar.gz'
            ]
        );
    } finally {
        temp_tar_path.unlink(missing_ok=True);
        try {
            core_v1.delete_namespaced_pod(sync_pod_name, namespace);
            wait_for_pod_deletion(core_v1, namespace, sync_pod_name);
        } except ApiException as exc {
            if (exc.status != 404) {
                raise ;
            }
        }
    }
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
        print(f"Syncing application code to PVC '{pvc_name}'...");
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
            print('requirements.txt exists');
            install_part = f"pip install -r /app/requirements.txt && jac serve {file_name}";
        } else {
            install_part = f"jac serve {file_name} ";
        }
        command = [
            'bash',
            '-c',
            f'export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -y git npm nodejs && git clone --branch jac-scale-fixes-accoemondate-jac-gpt --single-branch --depth 1 https://github.com/juzailmlwork/jaseci.git && cd ./jaseci && git submodule update --init --recursive && cd ../ && pip install pluggy && pip install jaclang && pip install -e  ./jaseci/jac-scale && pip install jac-client && cd ../ && jac create_jac_app client_app && cp -r ./app/* ./client_app && cd ./client_app && {install_part}'
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
    service = {
        'apiVersion': 'v1',
        'kind': 'Service',
        'metadata': {'name': f"{app_name}-service"},
        'spec': {
            'selector': {'app': app_name},
            'ports': [
                {
                    'protocol': 'TCP',
                    'port': container_port,
                    'targetPort': container_port,
                    'nodePort': node_port
                }
            ],
            'type': 'NodePort'
        }
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
        print('Checking MongoDB status...');
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
        print('Checking Redis status...');
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
    if check_deployment_status(node_port, path) {
        print(
            f"Deployment complete! Access Jaseci-app at http://localhost:{node_port}"
        );
    } else {
        print('Deployment failed or service not responding.');
    }
}
