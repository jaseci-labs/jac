import base64;
import os;
import tarfile;
import time;
import from collections.abc { Callable }
import from pathlib { Path }
import requests;
import urllib3;
import from dotenv { dotenv_values }
import from jaclang.scale._optdeps.kubernetes {
    client,
    config,
    ApiException,
    ConfigException
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }
import from requests.exceptions { RequestException }

glob COMPANION_DEFS: list = [
         ("", "Jaseci App", False),
         ("-redis", "Redis", False),
         ("-mongodb", "MongoDB", True),
         ("-prometheus", "Prometheus", False),
         ("-grafana", "Grafana", False),
         ("-redis-insight", "RedisInsight", False),
         ("-mongo-express", "Mongo Express", False),
         ("-ingress-nginx", "NGINX Ingress", False),

     ];

def check_pods_restarted(namespace: str, app_name: str) -> bool;

def parse_cpu_quantity(quantity: str) -> float;

def parse_memory_quantity(quantity: str) -> float;

def validate_resource_limits(
    cpu_request: (str | None),
    cpu_limit: (str | None),
    memory_request: (str | None),
    memory_limit: (str | None)
) -> None;

def load_env_variables(code_folder: str) -> list;

def create_k8s_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str]
) -> bool;

def delete_k8s_secret(
    core_v1: client.CoreV1Api, namespace: str, secret_name: str
) -> None;

def check_K8s_status -> None;

def delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None;

def ensure_namespace_exists(namespace: str) -> None;

def delete_namespace(namespace: str) -> None;

def check_deployment_status(
    node_port: int,
    path: str = '/docs',
    interval: int = 15,
    max_retries: int = 48,
    nlb_url: (str | None) = None,
    namespace: str = "default",
    app_name: str = "jaseci",
) -> tuple[bool, str];

def cluster_type -> str;

def get_cluster_provider -> ClusterProvider;

def ensure_pvc_exists(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    storage_size: str,
    storage_class: (str | None) = None,
    access_mode: str = 'ReadWriteOnce'
) -> None;

def parse_storage_quantity(quantity: str) -> int;

def resize_pvc_if_needed(
    core_v1: client.CoreV1Api, namespace: str, pvc_name: str, desired_size: str
) -> None;

def wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None;

def describe_pod_status(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, pod: any = None
) -> str;

def wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None;

def run_kubectl_command(args: list[str], cwd: str | Path | None = None) -> None;
