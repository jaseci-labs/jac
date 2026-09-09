import os;
import logging;
import from jaclang.scale.deploy.target.service_deployer { ServiceDeployer }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.server { sv_client }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { k8s_safe_name }
import from jaclang.scale.runtime.context.util {
    k8s_service_dns_url,
    in_cluster_namespace,
    DEFAULT_GATEWAY_PORT
}

glob logger = logging.getLogger(__name__);


def resolve_peer_url(svc_name: str, namespace: str, port: int) -> str {
    `override: str = sv_client.peer_url_from_env(svc_name);
    if `override {
        return `override;
    }
    key: str = sv_client.peer_url_env_key(svc_name);
    if key in os.environ {
        logger.debug(
            f"{key} is set but blank; resolving '{svc_name}' by naming convention"
        );
    }
    return k8s_service_dns_url(k8s_safe_name(svc_name), namespace, port);
}


obj K8sRuntimeServiceResolver(ServiceDeployer) {
    has registry: ServiceRegistry,
        target: str = "kubernetes",
        namespace: str = "default",
        port: int = DEFAULT_GATEWAY_PORT;

    def url_for(service_entry: ServiceEntry) -> str {
        return resolve_peer_url(service_entry.name, self.namespace, self.port);
    }

    def deploy_service(name: str) -> bool {
        logger.warning(
            f"K8sRuntimeServiceResolver.deploy_service({name}): admin op "
            "not yet wired. Use `jac scale deploy <file.jac>` for deployment."
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
            "`KubernetesTarget.destroy(app_name)` instead."
        );
        return False;
    }

    def deploy_all -> bool {
        logger.warning(
            "K8sRuntimeServiceResolver.deploy_all: use `jac scale deploy <file.jac>` instead."
        );
        return False;
    }
}


def build_k8s_registry(
    apps: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str] {
    namespace: str = in_cluster_namespace();
    registry: dict[str, str] = {};
    for svc_name in list(apps) {
        registry[str(svc_name)] = resolve_peer_url(str(svc_name), namespace, port);
    }
    return registry;
}
