import os;
import logging;
import from jaclang.scale.deploy.target.service_deployer { ServiceDeployer }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.server { sv_client }
import from jaclang.scale.runtime.context.util { DEFAULT_GATEWAY_PORT }
import from jaclang.scale.runtime.context.service_routing {
    ServiceRoute,
    resolve_service_route
}

glob logger = logging.getLogger(__name__),
     _config_load_warned: set[str] = set();


def resolve_peer_route(svc_name: str, namespace: str, port: int) -> ServiceRoute {
    `override: str = sv_client.peer_url_from_env(svc_name);
    if `override {
        return ServiceRoute(url=`override, host_header=None);
    }
    key: str = sv_client.peer_url_env_key(svc_name);
    if key in os.environ {
        logger.debug(
            f"{key} is set but blank; resolving '{svc_name}' by naming convention"
        );
    }
    kubernetes_cfg: dict[str, any] = {};
    app_scale_cfg: dict[str, any] = {};
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        scale_cfg = get_scale_config();
        kubernetes_cfg = scale_cfg.get_kubernetes_config();
        app_scale_cfg = scale_cfg.get_app_scale_config(svc_name);
        _config_load_warned.discard(svc_name);
    } except Exception as e {
        if svc_name not in _config_load_warned {
            _config_load_warned.add(svc_name);
            logger.warning(
                f"Could not load scale config while resolving '{svc_name}'; "
                f"treating it as not HTTP-activated: {e}"
            );
        }
    }
    return resolve_service_route(
        svc_name, namespace, port, kubernetes_cfg, app_scale_cfg
    );
}


def resolve_peer_url(svc_name: str, namespace: str, port: int) -> str {
    return resolve_peer_route(svc_name, namespace, port).url;
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


def build_k8s_registry_routes(
    routes: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, ServiceRoute] {
    import from jaclang.scale.runtime.context.util { in_cluster_namespace }
    namespace: str = in_cluster_namespace();
    result: dict[str, ServiceRoute] = {};
    for svc_name in list(routes) {
        result[str(svc_name)] = resolve_peer_route(str(svc_name), namespace, port);
    }
    return result;
}


def build_k8s_registry(
    apps: list[str] | dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str] {
    return {
        name: route.url
        for (name, route) in build_k8s_registry_routes(apps, port).items()
    };
}
