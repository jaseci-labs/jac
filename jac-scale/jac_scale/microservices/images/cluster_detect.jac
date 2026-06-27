import subprocess;
import from jac_scale._optdeps.kubernetes { config as k8s_config_lib, ConfigException }


glob CLUSTER_MINIKUBE: str = "minikube",
     CLUSTER_K3D: str = "k3d",
     CLUSTER_KIND: str = "kind",
     CLUSTER_REMOTE: str = "remote",
     CLUSTER_UNKNOWN: str = "unknown";


def _active_context_name -> str {
    try {
        (contexts, active_context) = k8s_config_lib.list_kube_config_contexts();
    } except ConfigException {
        return "";
    } except Exception {
        return "";
    }
    if active_context is None {
        return "";
    }
    return str(active_context.get("name", "")).lower();
}


def detect_cluster_type -> str {
    name = _active_context_name();
    if not name {
        return CLUSTER_UNKNOWN;
    }
    if name == "minikube" or name.startswith("minikube-") {
        return CLUSTER_MINIKUBE;
    }
    if name.startswith("k3d-") {
        return CLUSTER_K3D;
    }
    if name.startswith("kind-") {
        return CLUSTER_KIND;
    }
    return CLUSTER_REMOTE;
}


def k3d_cluster_name(ctx_name: str) -> str {
    lower = ctx_name.lower();
    if lower.startswith("k3d-") {
        return ctx_name[len("k3d-"):];
    }
    return ctx_name;
}


def kind_cluster_name(ctx_name: str) -> str {
    lower = ctx_name.lower();
    if lower.startswith("kind-") {
        return ctx_name[len("kind-"):];
    }
    return ctx_name;
}


def get_minikube_docker_env -> dict[str, str] {
    try {
        result = subprocess.run(
            ["minikube", "docker-env", "--shell=bash"],
            capture_output=True,
            text=True,
            timeout=10
        );
    } except FileNotFoundError {
        raise RuntimeError(
            "minikube CLI not found but kubeconfig context is 'minikube'. "
            "Install minikube (https://minikube.sigs.k8s.io/) or change kubectl context."
        );
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            "minikube docker-env timed out after 10s. Check `minikube status`."
        );
    }
    if result.returncode != 0 {
        raise RuntimeError(
            f"minikube docker-env failed (exit {result.returncode}): {result.stderr.strip()}"
        );
    }

    env_vars: dict[str, str] = {};
    for line in result.stdout.splitlines() {
        if not line.startswith("export ") {
            continue;
        }
        rest = line[len("export "):];
        if "=" not in rest {
            continue;
        }
        eq_idx = rest.find("=");
        key = rest[:eq_idx].strip();
        value = rest[eq_idx + 1:].strip();
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"' {
            value = value[1:-1];
        }
        env_vars[key] = value;
    }
    return env_vars;
}
