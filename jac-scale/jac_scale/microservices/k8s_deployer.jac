"""K8s runtime adapter for in-cluster operation. Implements `url_for`
(returns DNS hostname instead of loopback) so the gateway forwards to
services via K8s DNS. Selected by the get_sv_registry @hookimpl when
`KUBERNETES_SERVICE_HOST` is set. Lifecycle methods are no-op stubs -
deploy is owned by KubernetesMicroserviceTarget, runtime by K8s itself."""

import logging;
import from typing { Any }
import from jac_scale.microservices.deployer { ServiceDeployer }
import from jac_scale.microservices.service_registry { ServiceRegistry, ServiceEntry }
import from jac_scale.microservices.k8s_target { k8s_safe_name }
import from jac_scale.microservices._util {
    k8s_service_dns_url,
    in_cluster_namespace,
    DEFAULT_GATEWAY_PORT
}

glob logger = logging.getLogger(__name__);


"""Runtime ServiceDeployer for K8s. namespace + port are injected at
construction time (the hookimpl reads namespace from `POD_NAMESPACE` env)."""
obj KubernetesDeployer(ServiceDeployer) {
    has registry: ServiceRegistry,
        target: str = "kubernetes",
        namespace: str = "default",
        port: int = DEFAULT_GATEWAY_PORT;

    """DNS URL: `http://{k8s_safe_name(svc)}-service.{ns}.svc.cluster.local:{port}`."""
    def url_for(service_entry: ServiceEntry) -> str {
        return k8s_service_dns_url(
            k8s_safe_name(service_entry.name), self.namespace, self.port
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

    """Admin op stub. Future: kubectl scale + HPA-bound clamping."""
    def scale_service(name: str, replicas: int) -> bool {
        logger.warning(
            f"KubernetesDeployer.scale_service({name}, {replicas}): "
            "admin op not yet wired."
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


"""Build `{module_name: dns_url}` registry map for the get_sv_registry
hookimpl. Namespace from in_cluster_namespace(); port from jac.toml."""
def build_k8s_registry(
    routes: dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str] {
    namespace: str = in_cluster_namespace();
    registry: dict[str, str] = {};
    for svc_name in routes.keys() {
        registry[svc_name] = k8s_service_dns_url(
            k8s_safe_name(svc_name), namespace, port
        );
    }
    return registry;
}
