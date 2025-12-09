import base64;
import os;
import tarfile;
import time;
import from collections.abc { Callable }
import requests;
import urllib3;
import from dotenv { dotenv_values }
import from kubernetes { client, config }
import from kubernetes.client.rest { ApiException }
import from kubernetes.config.config_exception { ConfigException }
import from requests.exceptions { RequestException }
"""\n    Print a statement only if debug_only is True.\n\n    Args:\n        statement (str): The message to print.\n        debug_only (bool): If True, print the statement; otherwise, do nothing.\n    """
def debug_print(statement: str, debug_only: bool = False) -> None {
    if debug_only {
        print(statement);
    }
}

"""Load env variables in .env to aws beanstalk environment."""
def load_env_variables(code_folder: str) -> list {
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

"""\n    Checks if Kubernetes config is configured and the k8 API server is reachable.\n    """
def check_k8_status()  -> None {
    try {
        config.load_kube_config();
    } except ConfigException {
        try {
            config.load_incluster_config();
        } except ConfigException {
            raise None from Exception('Kubernetes is not configured on this machine.') ;
        }
    }
    try {
        v1 = client.CoreV1Api();
        v1.get_api_resources();
    } except (ApiException, urllib3.exceptions.HTTPError, OSError) {
        raise None from Exception(
            'Unable to connect to kubernetes APi.Check whether kubernetes cluster is up'
        ) ;
    }
}

"""Deploy example."""
def delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None {
    try {
        delete_func(name, namespace);
    } except ApiException as e {
        if (e.status == 404) {
            ;
        } else {
            raise ;
        }
    }
}

"""Delete all K8s resources (deployment, service, etc.) created for the app."""
def cleanup_k8_resources()  -> None {
    app_name = os.getenv('APP_NAME', 'jaseci');
    namespace = os.getenv('K8_NAMESPACE', 'default');
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
    pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace);
    for pvc in pvcs.items {
        if pvc.metadata.name.startswith(app_name) {
            try {
                core_v1.delete_namespaced_persistent_volume_claim(
                    pvc.metadata.name, namespace
                );
                print(f"Deleted PVC: {pvc.metadata.name}");
            } except client.exceptions.ApiException as e {
                print(f"Error deleting PVC '{pvc.metadata.name}': {e}");
            }
        }
    }
    print(f"All Kubernetes resources for '{app_name}' cleaned up successfully.");
}

"""\n    Ensure that a given namespace exists in the Kubernetes cluster.\n    If it doesn't exist and is not 'default', it will be created.\n    """
def ensure_namespace_exists(namespace: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        config.load_kube_config();
        core_v1 = client.CoreV1Api();
        core_v1.read_namespace(name=namespace);
        print(f"Namespace '{namespace}' already exists.");
    } except ApiException as e {
        if (e.status == 404) {
            print(f"Namespace '{namespace}' not found. Creating it...");
            core_v1.create_namespace(
                body={
                    'apiVersion': 'v1',
                    'kind': 'Namespace',
                    'metadata': {'name': namespace}
                }
            );
            print(f"Namespace '{namespace}' created successfully.");
        } else {
            raise ;
        }
    }
}

"""\n    Create a tar.gz file from the source directory using only os module.\n    """
def create_tarball(source_dir: str, tar_path: str) -> None {
    if not os.path.exists(source_dir) {
        raise FileNotFoundError(f"Source directory not found: {source_dir}") ;
    }
    os.makedirs((os.path.dirname(tar_path) or '.'), exist_ok=True);
    with tarfile.open(tar_path, 'w:gz') as tar {
        tar.add(source_dir, arcname='.');
    }
}

"""Create or update ConfigMap with binary tar.gz using Kubernetes API."""
def create_or_update_configmap(
    namespace: str, configmap_name: str, tar_path: str
) -> None {
    config.load_kube_config();
    v1 = client.CoreV1Api();
    with open(tar_path, 'rb') as f {
        encoded_data = base64.b64encode(f.read()).decode('utf-8');
    }
    body = client.V1ConfigMap(
        metadata=client.V1ObjectMeta(name=configmap_name),
        binary_data={'jaseci-code.tar.gz': encoded_data}
    );
    try {
        existing = v1.read_namespaced_config_map(configmap_name, namespace);
        body.metadata.resource_version = existing.metadata.resource_version;
        v1.patch_namespaced_config_map(
            name=configmap_name, namespace=namespace, body=body
        );
    } except ApiException as e {
        if (e.status == 404) {
            v1.create_namespaced_config_map(namespace, body);
        } else {
            raise ;
        }
    }
}

"""\n    Wait for a service on localhost at the given NodePort to become available.\n\n    """
def check_deployment_status(
    node_port: int,
    path: str = '/docs',
    initial_wait: int = 60,
    interval: int = 30,
    max_retries: int = 10
) -> bool {
    url = f"http://localhost:{node_port}{path}";
    time.sleep(initial_wait);
    for attempt in range(1, (max_retries + 1)) {
        try {
            response = requests.get(url);
            if (response.status_code == 200) {
                return True;
            }
        } except RequestException {
            ;
        }
        if (attempt < max_retries) {
            time.sleep(interval);
        }
    } else {
        return False;
    }
}
