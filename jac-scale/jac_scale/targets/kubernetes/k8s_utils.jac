"""Kubernetes utility functions for deployment."""
import os;
import time;
import tarfile;
import tempfile;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Any, Callable }
import from dotenv { dotenv_values }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }
import from kubernetes.config.config_exception { ConfigException }
import from requests.exceptions { RequestException }
import requests;
import urllib3;

"""Load environment variables from .env file."""
def load_env_variables(code_folder: str) -> list[dict[str, str]] {
    env_file = os.path.join(code_folder, '.env');
    env_vars = dotenv_values(env_file);
    env_list = [];
    if os.path.exists(env_file) {
        for (key, value) in env_vars.items() {
            env_list.append({'name': key, 'value': value});
        }
    }
    return env_list;
}

"""Check Kubernetes cluster status."""
def check_K8s_status() -> None {
    try {
        config.load_kube_config();
    } except ConfigException {
        try {
            config.load_incluster_config();
        } except ConfigException {
            raise Exception('Kubernetes is not configured on this machine.');
        }
    }
    try {
        v1 = client.CoreV1Api();
        v1.get_api_resources();
    } except (ApiException, urllib3.exceptions.HTTPError, OSError) {
        raise Exception('Unable to connect to kubernetes API. Check whether kubernetes cluster is up');
    }
}

"""Ensure namespace exists."""
def ensure_namespace_exists(namespace: str) -> None {
    if namespace == 'default' {
        return;
    }
    try {
        config.load_kube_config();
        core_v1 = client.CoreV1Api();
        core_v1.read_namespace(name=namespace);
    } except ApiException as e {
        if e.status == 404 {
            core_v1.create_namespace(
                body={
                    'apiVersion': 'v1',
                    'kind': 'Namespace',
                    'metadata': {'name': namespace}
                }
            );
        } else {
            raise;
        }
    }
}

"""Delete resource if it exists."""
def delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None {
    try {
        delete_func(name, namespace);
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }
}

"""Detect cluster type (aws or local)."""
def cluster_type() -> str {
    try {
        v1 = client.CoreV1Api();
        nodes = v1.list_node();
        if not nodes.items {
            return 'local';
        }
        for <>node in nodes.items {
            provider_id = <>node.spec.provider_id or '';
            if provider_id.startswith('aws://') {
                return 'aws';
            }
        }
        for <>node in nodes.items {
            labels = <>node.metadata.labels or {};
            if (
                'topology.kubernetes.io/region' in labels
                and <>any(
                    region in labels.get('topology.kubernetes.io/region', '')
                    for region in ['us-', 'eu-', 'ap-', 'ca-', 'sa-']
                )
                and (
                    'karpenter.sh/provisioner-name' in labels
                    or (
                        'kubernetes.io/os' in labels
                        and 'node.kubernetes.io/instance-type' in labels
                    )
                )
            ) {
                return 'aws';
            }
        }
        return 'local';
    } except Exception {
        return 'local';
    }
}

"""Check deployment status."""
def check_deployment_status(
    node_port: int,
    path: str = '/docs',
    initial_wait: int = 60,
    interval: int = 30,
    max_retries: int = 10,
    nlb_url: (str | None) = None
) -> bool {
    if nlb_url {
        url = f"{nlb_url.rstrip('/')}{path}";
    } else {
        url = f"http://localhost:{node_port}{path}";
    }
    time.sleep(initial_wait);
    for attempt in range(1, max_retries + 1) {
        try {
            response = requests.get(url, timeout=10);
            if response.status_code == 200 {
                return True;
            }
        } except RequestException as e {
            if attempt == max_retries {
                return False;
            }
        }
        if attempt < max_retries {
            time.sleep(interval);
        }
    }
    return False;
}

"""Ensure PVC exists."""
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
        if exc.status != 404 {
            raise;
        }
    }
    pvc_body: dict[str, Any] = {
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

"""Sync code to PVC."""
def sync_code_to_pvc(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    code_folder: str,
    app_name: str,
    sync_image: str
) -> None {
    sync_pod_name = f"{app_name}-code-sync";
    parent_dir = Path(code_folder).parent;
    toml_path = parent_dir / 'jac.toml';
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
        if exc.status == 409 {
            core_v1.delete_namespaced_pod(sync_pod_name, namespace);
            wait_for_pod_deletion(core_v1, namespace, sync_pod_name);
            core_v1.create_namespaced_pod(namespace, pod_body);
        } else {
            raise;
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
                'exec', '-n', namespace, sync_pod_name, '--',
                'sh', '-c', 'rm -rf /data/* && mkdir -p /data/workspace'
            ]
        );
        run_kubectl_command(
            [
                'cp', '-n', namespace, temp_tar_path.name,
                f"{sync_pod_name}:/tmp/jaseci-code.tar.gz"
            ],
            cwd=temp_tar_path.parent
        );
        run_kubectl_command(
            [
                'exec', '-n', namespace, sync_pod_name, '--',
                'sh', '-c', 'tar -xzf /tmp/jaseci-code.tar.gz -C /data/workspace && rm -f /tmp/jaseci-code.tar.gz'
            ]
        );
        if toml_path.is_file() {
            run_kubectl_command(
                [
                    'cp', '-n', namespace, 'jac.toml',
                    f"{sync_pod_name}:/data/workspace/jac.toml"
                ],
                cwd=parent_dir
            );
        }
    } finally {
        temp_tar_path.unlink(missing_ok=True);
        try {
            core_v1.delete_namespaced_pod(sync_pod_name, namespace);
            wait_for_pod_deletion(core_v1, namespace, sync_pod_name);
        } except ApiException as exc {
            if exc.status != 404 {
                raise;
            }
        }
    }
}

"""Run kubectl command."""
def run_kubectl_command(args: list[str], cwd: (str | Path | None) = None) -> None {
    if shutil.which('kubectl') is None {
        raise RuntimeError('kubectl is required to sync code to the PVC.');
    }
    try {
        subprocess.run(
            ['kubectl', *args], check=True, text=True, cwd=str(cwd) if cwd else None
        );
    } except subprocess.CalledProcessError as exc {
        raise RuntimeError(f"kubectl command failed: {' '.join(['kubectl', *args])}") from exc;
    }
}

"""Wait for pod deletion."""
def wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None {
    start_time = time.time();
    while (time.time() - start_time) < timeout {
        try {
            core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if exc.status == 404 {
                return;
            }
            raise;
        }
        time.sleep(2);
    }
    raise TimeoutError(f"Timed out waiting for pod '{pod_name}' deletion.");
}

"""Wait for pod phase."""
def wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None {
    start_time = time.time();
    while (time.time() - start_time) < timeout {
        try {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if exc.status == 404 {
                time.sleep(2);
                continue;
            }
            raise;
        }
        phase = (pod.status.phase or '').strip();
        if phase in target_phases {
            return;
        }
        if phase == 'Failed' {
            raise RuntimeError(f"Sync pod '{pod_name}' entered Failed state.");
        }
        time.sleep(2);
    }
    raise TimeoutError(
        f"Timed out while waiting for pod '{pod_name}' to reach phase {target_phases}."
    );
}

"""Create tarball."""
def create_tarball(source_dir: str, tar_path: str) -> None {
    if not os.path.exists(source_dir) {
        raise FileNotFoundError(f"Source directory not found: {source_dir}");
    }
    os.makedirs(os.path.dirname(tar_path) or '.', exist_ok=True);
    with tarfile.open(tar_path, 'w:gz') as tar {
        tar.add(source_dir, arcname='.');
    }
}

"""Validate resource limits."""
def validate_resource_limits(
    cpu_request: (str | None),
    cpu_limit: (str | None),
    memory_request: (str | None),
    memory_limit: (str | None)
) -> None {
    # Simple validation - can be enhanced
    if cpu_request and cpu_limit {
        # Basic check - can add parsing if needed
        pass;
    }
    if memory_request and memory_limit {
        # Basic check - can add parsing if needed
        pass;
    }
}

