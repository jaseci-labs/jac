import os;
import sys;

import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.frontend.constant { Constants as Con }
import type from jaclang.runtime.context { ExecutionContext }
import from jaclang.jac0core.ext_registry { base_stem }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.settings { ServeSettings }


obj PreparedInProcessRuntime {
    has server: any,
        transport_kind: str,
        client: any | None = None,
        _prior_ctx: (ExecutionContext | None) = None;

    def close {
        if self.client is not None {
            self.client.close();
            self.client = None;
        }

        Jac.set_shared_root_resolver(None);
        self.server = None;

        if self._prior_ctx is not None {
            Jac.set_context(self._prior_ctx);
        }
        self._prior_ctx = None;
    }
}


def _extensions_for(profile: str) -> list[ServerExtension] {
    if profile == "desktop" {
        return [];
    }
    if profile in ("test", "full") {
        return list(Jac.get_server_extensions());
    }
    raise ValueError(
        "unknown endpoint_profile '"
            + str(profile)
            + "' (expected 'desktop', 'test', or 'full')"
    );
}


def prepare_inprocess_runtime(
    jac_file: str,
    base_path: str,
    endpoint_profile: str = "full",
    setup_background_services: bool = True,
    transport_kind: str = "testclient",
    extensions: (list[ServerExtension] | None) = None,
    overrides: (dict[str, any] | None) = None
) -> PreparedInProcessRuntime {
    import from jaclang.testing.testkit { ServingTestClient }

    if transport_kind not in ("testclient", "listener") {
        raise NotImplementedError(
            "transport_kind='"
                + str(transport_kind)
                + "' is not implemented; 'testclient' drives the app in-memory and "
                + "'listener' prepares a server for serve_background()."
        );
    }

    import from jaclang.scale.plugin { mark_scale_runtime }
    (base, _) = os.path.split(jac_file);
    base = base or "./";
    mod = base_stem(jac_file);
    os.makedirs(base_path, exist_ok=True);
    mark_scale_runtime();
    Jac.set_base_path(base_path);

    prior_ctx = Jac.exec_ctx;
    mach = Jac.create_j_context(user_root=None);
    Jac.set_context(mach);
    try {
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        import from jaclang.project.config { get_config_for_dir }
        import from jaclang.server.assembly { service_apps }
        import from jaclang.compiler.driver.application { prepare_application }
        import from jaclang.runtime.prepared { initialize_application }
        cfg = get_config_for_dir(base);
        served = cfg.app_for_path(os.path.abspath(jac_file))
            if cfg is not None
            else None;
        project_root = str(cfg.project_root) if cfg and cfg.project_root else base;
        static_only = bool((overrides or {}).get('static_only', False));
        services = service_apps(cfg, served)
            if cfg and served and not static_only
            else [];
        prepared = prepare_application(
            jac_file,
            Jac.get_program(),
            project_root,
            [svc.entry_path(project_root) for svc in services]
        );
        mod = initialize_application(
            prepared, cfg, None if static_only else served
        ).__name__;

        serve_overrides: dict[str, any] = {'no_client': True};
        serve_overrides.update(overrides or {});
        server = JacAPIServer(
            module_name=mod,
            port=int(serve_overrides.get('port') or 0),
            base_path=base_path,
            module_file=jac_file,
            settings=ServeSettings.load(base_path, serve_overrides),
            extensions=_extensions_for(endpoint_profile) + list(extensions or [])
        );
        server.load_module();
        server._ensure_internal_users();
        app = server.build_app();
        if setup_background_services {
            server._register_scheduled_tasks();
            server.scheduler.start_if_pending();
            for ext in (server.extensions or []) {
                ext.on_worker_start(server);
            }
        }
        client = (
            ServingTestClient(app=app, raise_server_exceptions=False)
                if transport_kind == "testclient"
                else None
        );
        return PreparedInProcessRuntime(
            server=server,
            transport_kind=transport_kind,
            client=client,
            _prior_ctx=prior_ctx
        );
    } except Exception {
        if mod in Jac.loaded_modules {
            del Jac.loaded_modules[mod];
        }
        if mod in sys.modules {
            del sys.modules[mod];
        }
        Jac.set_shared_root_resolver(None);
        if prior_ctx is not None {
            Jac.set_context(prior_ctx);
        }
        mach.close();
        raise;
    }
}
