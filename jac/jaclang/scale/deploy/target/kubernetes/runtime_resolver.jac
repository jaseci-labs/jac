import logging;
import from jaclang.scale.deploy.target.service_deployer { ServiceDeployer }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}
import from jaclang.scale.runtime.context.util {
    k8s_safe_name,
    k8s_service_dns_url,
    in_cluster_namespace,
    DEFAULT_GATEWAY_PORT
}
import from jaclang.scale.runtime.context.service_routing {
    ServiceRoute,
    resolve_service_route
}

glob logger = logging.getLogger(__name__),
     _config_load_warned: set[str] = set(),
     _sv_service_routes_warned: bool = False;


def resolve_peer_route(svc_name: str, namespace: str, port: int) -> ServiceRoute {
    kubernetes_cfg: dict[str, any] = {};
    svc_cfg: dict[str, any] = {};
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        scale_cfg = get_scale_config();
        kubernetes_cfg = scale_cfg.get_kubernetes_config();
        svc_cfg = dict(
            scale_cfg.get_microservices_config().get("services", {}).get(svc_name, {})
        );
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
    return resolve_service_route(svc_name, namespace, port, kubernetes_cfg, svc_cfg);
}


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
            "`KubernetesTarget.destroy(app_name)` instead."
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


def build_k8s_registry_routes(
    routes: dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, ServiceRoute] {
    namespace: str = in_cluster_namespace();
    result: dict[str, ServiceRoute] = {};
    for svc_name in routes.keys() {
        result[svc_name] = resolve_peer_route(svc_name, namespace, port);
    }
    return result;
}


def build_k8s_registry(
    routes: dict[str, str], port: int = DEFAULT_GATEWAY_PORT
) -> dict[str, str] {
    return {
        name: route.url
        for (name, route) in build_k8s_registry_routes(routes, port).items()
    };
}


"""Every peer's route (url + interceptor Host override) in K8s mode, {} elsewhere.

The one source get_sv_registry, sv-to-sv RPC and the gateway registry all read,
so a scale-to-zero peer is reached through the interceptor on every path. The
lookup fails for all services at once, so it warns once until it recovers.
"""
def get_sv_service_routes -> dict[str, ServiceRoute] {
    import os;
    if "KUBERNETES_SERVICE_HOST" not in os.environ {
        return {};
    }
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        routes: dict[str, str] = ms_cfg.get("routes", {});
        port: int = int(ms_cfg.get("gateway_port", 8000));
        result = build_k8s_registry_routes(routes, port);
        _sv_service_routes_warned = False;
        return result;
    } except Exception as e {
        if not _sv_service_routes_warned {
            _sv_service_routes_warned = True;
            logger.warning(f"K8s get_sv_service_routes failed: {e}");
        }
        return {};
    }
}
