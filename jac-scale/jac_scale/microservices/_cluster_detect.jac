"""K8s cluster type detection for the auto-build pipeline.

Reads the active kubeconfig context name and classifies it as minikube
/ k3d / kind / remote / unknown so _image_build can pick the right
image-distribution strategy (internal docker daemon / `<tool> image import` /
registry push).
"""

import subprocess;
import from typing { Any }
import from jac_scale._optdeps.kubernetes { config as k8s_config_lib, ConfigException }


glob CLUSTER_MINIKUBE: str = "minikube",
     CLUSTER_K3D: str = "k3d",
     CLUSTER_KIND: str = "kind",
     CLUSTER_REMOTE: str = "remote",
     CLUSTER_UNKNOWN: str = "unknown";


"""Active kubeconfig context name (lowercased), '' on failure."""
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


"""Classify kubeconfig context: minikube / k3d-* / kind-* / other.
Caller handles CLUSTER_UNKNOWN (no kubeconfig / no active context)."""
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


"""`k3d-mycluster` -> `mycluster` (k3d image import takes the bare name)."""
def k3d_cluster_name(ctx_name: str) -> str {
    lower = ctx_name.lower();
    if lower.startswith("k3d-") {
        return ctx_name[len("k3d-"):];
    }
    return ctx_name;
}


"""`kind-mycluster` -> `mycluster` (kind load takes the bare name)."""
def kind_cluster_name(ctx_name: str) -> str {
    lower = ctx_name.lower();
    if lower.startswith("kind-") {
        return ctx_name[len("kind-"):];
    }
    return ctx_name;
}


"""Parse `minikube docker-env --shell=bash` output into an env dict for
`subprocess.run(..., env=...)` so docker build lands in minikube's daemon."""
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
        # Strip surrounding double-quotes that minikube emits.
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"' {
            value = value[1:-1];
        }
        env_vars[key] = value;
    }
    return env_vars;
}
