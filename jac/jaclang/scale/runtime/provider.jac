import os;
import type from jaclang.runtime.context { ExecutionContext }
import type from jaclang.server.server { JacAPIServer as JacServer, ServerExtension }
import type from jaclang.data.storage { Storage }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.events.streams.postgres { PgEventStream }
import from jaclang.server.shared_store { shared_store as _pg_anchor }
import from jaclang.scale.state.pg_state_backend { PgStateBackend as _state_anchor }

def scale_runtime_configured -> bool {
    if (
        os.environ.get("JAC_SCALE_RUNTIME") == "1"
        or os.environ.get("JAC_SV_SIBLING") == "1"
    ) {
        return True;
    }
    db = get_scale_config().get_database_config();
    return bool(
        db.get("url") or db.get("postgres_url") or os.environ.get("JAC_DB_URL")
    );
}

def mark_scale_runtime {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
}

glob _sv_service_routes_warned: bool = False;

class JacScaleRuntime {
    static def create_j_context(
        user_root: (str | None),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None
    ) -> ExecutionContext | None {
        if not scale_runtime_configured() {
            return None;
        }
        import from jaclang.scale.memory.context { JScaleExecutionContext }
        ctx = JScaleExecutionContext();
        if user_root is not None {
            ctx.set_user_root(user_root);
        }
        return ctx;
    }

    static def create_server(jac_server: JacServer, host: str, port: int) {
        return None;
    }

    static def get_server_extensions -> list[ServerExtension] {
        import from jaclang.scale.server.extensions { scale_extensions }
        return scale_extensions();
    }

    static def store(
        base_path: str = "./storage", create_dirs: bool = True
    ) -> Storage {
        import from jaclang.scale.storage.factory { StorageFactory }
        return StorageFactory.get_default(base_path, create_dirs);
    }

    static def get_sv_service_routes -> dict[str, any] {
        """K8s-mode-only bundled resolution: url + interceptor Host-header
        override together, per service, from ONE call -- the single source
        of truth get_sv_registry() (below) and sv-to-sv RPC (rpc.jac) both
        read from, so they can never independently drift.

        This whole lookup fails or succeeds atomically for every service at
        once (it fails before any per-service resolution starts), so a
        broken route table -- unreachable or malformed config -- would
        otherwise warn on every sv-to-sv call and every rpc.jac fallback
        that reaches here a second time through get_sv_registry(). Warn
        once until it recovers.""";
        import os;
        if "KUBERNETES_SERVICE_HOST" not in os.environ {
            return {};
        }
        try {
            import from jaclang.scale.config.config_loader { get_scale_config }
            import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
                build_k8s_registry_routes
            }
            import from jaclang.scale.runtime.fleet { fleet_from_env }
            fleet = fleet_from_env();
            names: list[str] = fleet.names() if fleet is not None else [];
            port: int = int(
                get_scale_config().get_gateway_config().get("gateway_port", 8000)
            );
            routes = build_k8s_registry_routes(names, port);
            _sv_service_routes_warned = False;
            return routes;
        } except Exception as e {
            if not _sv_service_routes_warned {
                _sv_service_routes_warned = True;
                import logging;
                logging.getLogger(__name__).warning(
                    f"K8s get_sv_service_routes failed: {e}"
                );
            }
            return {};
        }
    }

    static def get_sv_registry -> dict[str, str] {
        import os;
        import from jaclang.server { sv_client }

        if "KUBERNETES_SERVICE_HOST" not in os.environ {
            return dict(sv_client._registry);
        }

        routes = JacScaleRuntime.get_sv_service_routes();
        if not routes {
            return dict(sv_client._registry);
        }
        return {name: route.url for (name, route) in routes.items()};
    }

    static def sv_transport_available -> bool {
        return True;
    }

    static def sv_service_call(
        app: str,
        func_name: str,
        args: dict[str, any],
        headers: dict[str, str] | None = None
    ) -> any {
        import from jaclang.scale.runtime.transport.transport { http_transport }
        return http_transport().call_function(app, func_name, args, headers=headers);
    }

    static def sv_walker_call(
        app: str,
        walker_name: str,
        args: dict[str, any],
        stub_cls: any,
        headers: dict[str, str] | None = None
    ) -> any {
        import from jaclang.scale.runtime.transport.transport { http_transport }
        return http_transport().call_walker(
            app, walker_name, args, stub_cls, headers=headers
        );
    }
}
