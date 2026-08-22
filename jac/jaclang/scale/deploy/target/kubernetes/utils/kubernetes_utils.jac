import os;
import time;
import from pathlib { Path }
import from jaclang.scale._optdeps.kubernetes {
    client,
    config,
    ApiException,
    ConfigException
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }

glob PSS_ENFORCE_LABEL: str = "pod-security.kubernetes.io/enforce",
     PSS_WARN_LABEL: str = "pod-security.kubernetes.io/warn",
     PSS_SOURCE_LABEL: str = "jac-scale.jaseci.org/pss-enforce-source";

def default_pss_labels -> dict[str, str];

def privileged_pss_labels(existing: dict[str, str]) -> dict[str, str] | None;

glob COMPANION_DEFS: list = [
         ("", "Jaseci App", False),
         ("-postgres", "PostgreSQL", True),
         ("-prometheus", "Prometheus", False),
         ("-grafana", "Grafana", False),
         ("-ingress-nginx", "NGINX Ingress", False),

     ];

def _resolve_current_rs_hashes(namespace: str, selector: str) -> set;

def _refresh_rs_hashes(
    namespace: str, selector: str, current: (set | None)
) -> (set | None);

def create_k8s_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str]
) -> str;

def delete_k8s_secret(
    core_v1: client.CoreV1Api, namespace: str, secret_name: str
) -> None;

def delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None;

def ensure_namespace_exists(namespace: str) -> None;

def delete_namespace(namespace: str) -> None;

def cluster_type -> str;

def get_cluster_provider -> ClusterProvider;

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
