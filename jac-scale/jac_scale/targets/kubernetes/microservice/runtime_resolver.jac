"""K8s in-cluster URL resolver. Implements `url_for` (DNS hostname
instead of loopback) so the gateway forwards via K8s DNS. Selected by
the get_sv_registry @hookimpl when `KUBERNETES_SERVICE_HOST` is set.
Lifecycle methods are no-op stubs; deploy is owned by
KubernetesMicroserviceTarget, runtime by K8s itself."""

import logging;
import from jac_scale.abstractions.service_deployer { ServiceDeployer }
import from jac_scale.microservices.service_registry { ServiceRegistry, ServiceEntry }
import from jac_scale.targets.kubernetes.microservice.manifest_builder { k8s_safe_name }
import from jac_scale.microservices.runtime.util {
    k8s_service_dns_url,
    in_cluster_namespace,
    DEFAULT_GATEWAY_PORT
}

glob logger = logging.getLogger(__name__);


obj K8sRuntimeServiceResolver(ServiceDeployer) {
    has registry: ServiceRegistry,
        target: str = "kubernetes",
        namespace: str = "default",
        port: int = DEFAULT_GATEWAY_PORT;

    def url_for(service_entry: ServiceEntry) -> str {
        return k8s_service_dns_url(
            k8s_safe_name(service_entry.name), self.namespace, self.port
        );
    }

    # Lifecycle stubs: pod lifecycle is K8s controller's job.
    def deploy_service(name: str) -> bool {
        logger.warning(
            f"K8sRuntimeServiceResolver.deploy_service({name}): admin op "
            "not yet wired. Use `jac start --scale` for deployment."
        );
        return False;
    }

    def stop_service(name: str) -> bool {
        logger.warning(
            f"K8sRuntimeServiceResolver.stop_service({name}): admin op not yet wired."
        );
        return False;
    }

    def restart_service(name: str) -> bool {
        logger.warning(
            f"K8sRuntimeServiceResolver.restart_service({name}): admin op not yet wired."
        );
        return False;
    }

    def scale_service(name: str, replicas: int) -> bool {
        logger.warning(
            f"K8sRuntimeServiceResolver.scale_service({name}, {replicas}): "
            "admin op not yet wired."
        );
        return False;
    }

    def status -> dict[str, dict] {
        return {};
    }

    def get_logs(name: str, lines: int = 50) -> str {
        return "";
    }

    def destroy_all -> bool {
        logger.warning(
            "K8sRuntimeServiceResolver.destroy_all: use "
            "`KubernetesMicroserviceTarget.destroy(app_name)` instead."
        );
        return False;
    }

    def deploy_all -> bool {
        logger.warning(
            "K8sRuntimeServiceResolver.deploy_all: use `jac start --scale` instead."
        );
        return False;
    }
}


"""Build `{module_name: dns_url}` registry map for the get_sv_registry
hookimpl."""
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
