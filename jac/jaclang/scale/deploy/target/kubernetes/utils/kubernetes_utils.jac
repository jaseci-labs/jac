import os;
import time;
import from pathlib { Path }

glob _LOCAL_FALLBACK_NOTE: str = (
         "Falling back to local provider semantics: service URLs will be "
         "reported as localhost node ports and no load balancer endpoint will "
         "be waited for. If this is a managed cluster, the reported URLs will "
         "be wrong."
     );

glob PSS_ENFORCE_LABEL: str = "pod-security.kubernetes.io/enforce",
     PSS_WARN_LABEL: str = "pod-security.kubernetes.io/warn",
     PSS_SOURCE_LABEL: str = "jac-scale.jaseci.org/pss-enforce-source",
     NAMESPACE_OWNER_LABEL: str = "jac-scale.jaseci.org/owned-by";

def default_pss_labels -> dict[str, str];

def privileged_pss_labels(existing: dict[str, str]) -> dict[str, str] | None;

def released_pss_labels(
    namespace: str, existing: dict[str, str]
) -> dict[str, str | None];

glob BASELINE_ALLOWED_CAPABILITIES: frozenset[str] = frozenset(
         [
             "AUDIT_WRITE",
             "CHOWN",
             "DAC_OVERRIDE",
             "FOWNER",
             "FSETID",
             "KILL",
             "MKNOD",
             "NET_BIND_SERVICE",
             "SETFCAP",
             "SETGID",
             "SETPCAP",
             "SETUID",
             "SYS_CHROOT"
         ]
     );

glob BASELINE_SELINUX_TYPES: frozenset[str] = frozenset(
         ["container_t", "container_init_t", "container_kvm_t", "container_engine_t"]
     ),
     BASELINE_SAFE_SYSCTLS: frozenset[str] = frozenset(
         [
             "kernel.shm_rmid_forced",
             "net.ipv4.ip_local_port_range",
             "net.ipv4.ip_local_reserved_ports",
             "net.ipv4.ip_unprivileged_port_start",
             "net.ipv4.ping_group_range",
             "net.ipv4.tcp_fin_timeout",
             "net.ipv4.tcp_keepalive_intvl",
             "net.ipv4.tcp_keepalive_probes",
             "net.ipv4.tcp_keepalive_time",
             "net.ipv4.tcp_syncookies"
         ]
     );

def security_context_escapes_baseline(ctx: any) -> bool;

def pod_spec_escapes_baseline(spec: any) -> bool;

def job_finished(job: any) -> bool;

glob COMPANION_DEFS: list[tuple[str, str, bool]] = [
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

def resolve_minted_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str],
    key: str,
    fresh: str
) -> bool;

def delete_k8s_secret(
    core_v1: client.CoreV1Api, namespace: str, secret_name: str
) -> None;

def delete_if_exists(
    delete_func: Callable, name: str, namespace: str, kind: str
) -> None;

def ensure_namespace_exists(namespace: str, owner: str) -> None;

def namespace_is_owned(core_v1: client.CoreV1Api, namespace: str, owner: str) -> bool;

def delete_namespace(core_v1: client.CoreV1Api, namespace: str) -> None;

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

obj KubectlCluster {
    has args: list[str] = [],
        env: dict[str, str] = {};

    def command(args: list[str]) -> list[str];
    def environ -> dict[str, str];
}

def kubectl_cluster(kube_context: str = "", kubeconfig: str = "") -> KubectlCluster;

def in_cluster_kubectl -> KubectlCluster;

def run_kubectl_command(
    args: list[str], kubectl: KubectlCluster, cwd: str | Path | None = None
) -> None;
