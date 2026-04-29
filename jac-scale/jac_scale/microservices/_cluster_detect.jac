"""K-track P0.5: K8s cluster type detection for the auto-build pipeline.

The auto-build path needs to know what kind of cluster it's deploying
to so it can pick the right image-distribution strategy:

  - minikube: shell out to `minikube docker-env` and build inside
              minikube's internal docker daemon (image lands in cluster)
  - k3d:      docker build on host, then `k3d image import` into cluster
  - kind:     docker build on host, then `kind load docker-image` into cluster
  - remote:   docker build with <registry>/<image>:<tag>, then `docker push`

Detection happens by reading the active kubeconfig context name. Most
local cluster managers use a stable naming convention (`minikube`,
`k3d-<name>`, `kind-<name>`); anything else we treat as `remote`.
"""

import subprocess;
import from typing { Any }
import from jac_scale._optdeps.kubernetes { config as k8s_config_lib, ConfigException }


# Cluster-type sentinels. String literals so callers can switch on them
# without importing an enum (which jac sometimes doesn't import cleanly
# across modules).
glob CLUSTER_MINIKUBE: str = "minikube",
     CLUSTER_K3D: str = "k3d",
     CLUSTER_KIND: str = "kind",
     CLUSTER_REMOTE: str = "remote",
     CLUSTER_UNKNOWN: str = "unknown";


"""Read active kubeconfig context name (lowercased), or '' on failure."""
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


"""Detect the K8s cluster type from the active kubeconfig context.

Returns one of:
  CLUSTER_MINIKUBE - context name == "minikube" (or starts with "minikube")
  CLUSTER_K3D      - context name starts with "k3d-"
  CLUSTER_KIND     - context name starts with "kind-"
  CLUSTER_REMOTE   - any other named context (we assume real cluster)
  CLUSTER_UNKNOWN  - kubeconfig couldn't be read or no active context

Caller is responsible for handling CLUSTER_UNKNOWN appropriately
(typically: error with "configure a cluster or run minikube start").
"""
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


"""Extract the local cluster name from a k3d-* context name.

E.g. context "k3d-mycluster" -> "mycluster". k3d's CLI (`k3d image
import ... -c <name>`) takes the bare cluster name, not the prefixed
context name.
"""
def k3d_cluster_name(ctx_name: str) -> str {
    lower = ctx_name.lower();
    if lower.startswith("k3d-") {
        return ctx_name[len("k3d-"):];
    }
    return ctx_name;
}


"""Extract the local cluster name from a kind-* context name.

E.g. context "kind-mycluster" -> "mycluster". kind's CLI (`kind load
docker-image ... --name <name>`) takes the bare cluster name.
"""
def kind_cluster_name(ctx_name: str) -> str {
    lower = ctx_name.lower();
    if lower.startswith("kind-") {
        return ctx_name[len("kind-"):];
    }
    return ctx_name;
}


"""Run `minikube docker-env --shell=bash` and parse the env exports.

Returns a dict of env vars (DOCKER_HOST, DOCKER_TLS_VERIFY,
DOCKER_CERT_PATH, MINIKUBE_ACTIVE_DOCKERD) ready to merge into
subprocess.run's `env` arg. Raises RuntimeError if minikube is not
installed or the command fails.

Used by the minikube auto-build path so `docker build` lands the image
in minikube's internal daemon (where K8s can pull it without a
registry).
"""
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
            "minikube CLI not found in PATH but kubeconfig context is "
            "'minikube'. Install minikube "
            "(https://minikube.sigs.k8s.io/docs/start/) or change kubectl "
            "context."
        );
    } except subprocess.TimeoutExpired {
        raise RuntimeError(
            "minikube docker-env timed out after 10s. Try "
            "`minikube status` to verify the cluster is responsive."
        );
    }
    if result.returncode != 0 {
        raise RuntimeError(
            f"minikube docker-env failed (exit {result.returncode}): "
            f"{result.stderr.strip()}"
        );
    }

    env_vars: dict[str, str] = {};
    for line in result.stdout.splitlines() {
        # Lines look like:  export DOCKER_HOST="tcp://192.168.49.2:2376"
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
        # Strip surrounding double-quotes (minikube emits them by default)
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"' {
            value = value[1:-1];
        }
        env_vars[key] = value;
    }
    return env_vars;
}
