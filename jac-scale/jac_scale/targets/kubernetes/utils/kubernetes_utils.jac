"""Kubernetes utility functions for deployment operations."""
import base64;
import os;
import tarfile;
import time;
import from collections.abc { Callable }
import from pathlib { Path }
import requests;
import urllib3;
import from dotenv { dotenv_values }
import from kubernetes { client, config }
import from kubernetes.client.rest { ApiException }
import from kubernetes.config.config_exception { ConfigException }
import from requests.exceptions { RequestException }

def check_pods_restarted(namespace: str, app_name: str) -> bool;

def debug_print(statement: str, debug_only: bool = False) -> None;

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

def exclude_folders(tarinfo: tarfile.TarInfo) -> Optional[tarfile.TarInfo];

def create_tarball(source_dir: str, tar_path: str) -> None;

def create_or_update_configmap(
    namespace: str, configmap_name: str, tar_path: str
) -> None;

def check_deployment_status(
    node_port: int,
    path: str = '/docs',
    interval: int = 15,
    max_retries: int = 30,
    nlb_url: (str | None) = None,
    namespace: str = "default",
    app_name: str = "jaseci",
) -> tuple[bool, str];

def cluster_type -> str;

def ensure_pvc_exists(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    storage_size: str,
    storage_class: (str | None) = None,
    access_mode: str = 'ReadWriteOnce'
) -> None;

def wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None;

def wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None;

def run_kubectl_command(args: list[str], cwd: str | Path | None = None) -> None;

def sync_code_to_pvc(
    core_v1: client.CoreV1Api,
    namespace: str,
    pvc_name: str,
    code_folder: str,
    app_name: str,
    sync_image: str
) -> None;
