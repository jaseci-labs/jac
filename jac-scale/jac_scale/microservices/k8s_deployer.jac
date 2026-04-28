"""K8s runtime adapter (mirrors LocalDeployer for in-cluster operation).

Sits at the runtime plane: when the gateway pod boots and needs to
forward to a service, `url_for` returns the K8s DNS hostname rather
than a localhost loopback. Selected at runtime via the `get_sv_registry`
@hookimpl in plugin.jac when `KUBERNETES_SERVICE_HOST` is set (which
K8s injects into every pod).

K4 scope: `url_for` returning DNS. The lifecycle methods (`deploy_service`,
`stop_service`, `restart_service`, `scale_service`, `status`, `get_logs`,
`destroy_all`, `deploy_all`) are admin operations that map to kubectl
calls - they're stubbed to no-op in K4 because:
  - Deploy lifecycle is owned by `KubernetesMicroserviceTarget` at
    `jac start --scale` time (K1-K3), not by this runtime adapter.
  - In-cluster admin commands (`jac scale stop orders` from inside a
    pod) are a future K-task; the K8s controller already handles
    most of the equivalent semantics (a Deployment scale-to-0 stops
    the service; a rollout-restart is a restart).
"""

import logging;
import from typing { Any }
import from jac_scale.microservices.deployer { ServiceDeployer }
import from jac_scale.microservices.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jac_scale.microservices.k8s_target { k8s_safe_name }

glob logger = logging.getLogger(__name__);


"""Runtime ServiceDeployer for K8s. Returns DNS-based URLs.

Construction:
    KubernetesDeployer(
        registry=service_registry,
        namespace="prod",
        port=8000,
    )

The namespace + port are injected at construction time rather than
read from KubernetesConfig, because this object lives in the runtime
plane (inside a pod) where KubernetesConfig.from_dict isn't always
the right source. The hookimpl that creates instances reads namespace
from the `POD_NAMESPACE` env var (downward API) and falls back to
the configured value if not set.
"""
obj KubernetesDeployer(ServiceDeployer) {
    has registry: ServiceRegistry,
        target: str = "kubernetes",
        namespace: str = "default",
        port: int = 8000;

    """Return the DNS-based URL for a microservice.

    Format: `http://{k8s_safe_name(svc)}-service.{namespace}.svc.cluster.local:{port}`

    This IS the runtime override that lets the gateway resolve services
    in-cluster without any code changes. The gateway calls
    `JacRuntime.get_sv_registry()` -> hookimpl returns DNS map ->
    `gateway.resolve_target_url` reads from that map.
    """
    def url_for(service_entry: ServiceEntry) -> str {
        name = k8s_safe_name(service_entry.name);
        return (
            f"http://{name}-service.{self.namespace}"
            f".svc.cluster.local:{self.port}"
        );
    }

    """Admin op stub. Pod lifecycle is K8s controller's job.

    Future: invoke `kubectl rollout restart deployment/{name}-deployment`
    or the equivalent kubernetes Python client call.
    """
    def deploy_service(name: str) -> bool {
        logger.warning(
            f"KubernetesDeployer.deploy_service({name}): admin op not "
            "yet wired. Use `jac start --scale` for deployment."
        );
        return False;
    }

    """Admin op stub. Use `kubectl scale deployment/{name}-deployment --replicas=0`."""
    def stop_service(name: str) -> bool {
        logger.warning(
            f"KubernetesDeployer.stop_service({name}): admin op not yet wired."
        );
        return False;
    }

    """Admin op stub. Use `kubectl rollout restart`."""
    def restart_service(name: str) -> bool {
        logger.warning(
            f"KubernetesDeployer.restart_service({name}): admin op not yet wired."
        );
        return False;
    }

    """Admin op stub. K6 will wire this to kubectl scale + HPA bounds."""
    def scale_service(name: str, replicas: int) -> bool {
        logger.warning(
            f"KubernetesDeployer.scale_service({name}, {replicas}): "
            "admin op not yet wired. K6 adds HPA-aware scaling."
        );
        return False;
    }

    """Read-only status snapshot. Future: `kubectl get pods -l app=<name>`."""
    def status -> dict[str, dict] {
        return {};
    }

    """Future: `kubectl logs -l app=<name> --tail=<lines>`."""
    def get_logs(name: str, lines: int = 50) -> str {
        return "";
    }

    """Tear-down stub. Use `KubernetesMicroserviceTarget.destroy()` instead."""
    def destroy_all -> bool {
        logger.warning(
            "KubernetesDeployer.destroy_all: use "
            "`KubernetesMicroserviceTarget.destroy(app_name)` instead."
        );
        return False;
    }

    """Deploy stub. Use `jac start --scale` (calls deploy() on the target)."""
    def deploy_all -> bool {
        logger.warning(
            "KubernetesDeployer.deploy_all: use `jac start --scale` instead."
        );
        return False;
    }
}


"""Build a DNS-based registry map from configured routes + namespace + port.

Used by the `get_sv_registry` @hookimpl in jac-scale's plugin when
running inside a K8s pod. Returns `{module_name: dns_url, ...}` matching
the shape jaclang expects.

Namespace resolution order:
  1. `POD_NAMESPACE` env var (set via downward API on the pod spec)
  2. `/var/run/secrets/kubernetes.io/serviceaccount/namespace` file
  3. fall back to `default`

Port comes from `[plugins.scale.microservices.gateway_port]` in jac.toml.
"""
def build_k8s_registry(routes: dict[str, str], port: int = 8000) -> dict[str, str] {
    import os;
    namespace: str = os.environ.get("POD_NAMESPACE", "");
    if not namespace {
        try {
            ns_file = "/var/run/secrets/kubernetes.io/serviceaccount/namespace";
            with open(ns_file) as f {
                namespace = f.read().strip();
            }
        } except Exception {
            namespace = "default";
        }
    }

    registry: dict[str, str] = {};
    for svc_name in routes.keys() {
        name = k8s_safe_name(svc_name);
        registry[svc_name] = (
            f"http://{name}-service.{namespace}.svc.cluster.local:{port}"
        );
    }
    return registry;
}
