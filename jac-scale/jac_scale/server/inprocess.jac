import os;
import sys;

import from jaclang { JacRuntime as Jac, plugin_manager }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.ext_registry { base_stem }
import from jac_scale.server.serve { JacAPIServer }


obj PreparedInProcessRuntime {
    has server: any,
        transport_kind: str,
        client: any | None = None,
        _prior_ctx: any = None;

    def close {
        if self.client is not None {
            self.client.close();
            self.client = None;
        }

        Jac.set_shared_root_resolver(None);
        self.server = None;

        Jac.set_context(self._prior_ctx);
        self._prior_ctx = None;
    }
}


def _register_endpoint_profile(server: any, profile: str) {
    if profile == "desktop" {
        server.register_health_endpoint();
        server.register_auth_endpoints();
        server.register_walkers_endpoints();
        server.register_functions_endpoints();
    } elif profile == "test" {
        server.register_health_endpoint();
        server.register_auth_endpoints();
        server.register_graph_endpoint();
        server.register_admin_endpoints();
        server.register_llm_telemetry_endpoints();
        server.register_workloads_endpoints();
        server.register_walkers_endpoints();
        server.register_functions_endpoints();
        server.register_webhook_endpoints();
        server.register_static_file_endpoint();
        server.register_page_endpoint();
        server.register_client_js_endpoint();
    } elif profile == "full" {
        server._register_endpoints();
    } else {
        raise ValueError(
            "unknown endpoint_profile '" + str(profile) + "' (expected 'desktop', 'test', or 'full')"
        );
    }
}


def prepare_inprocess_runtime(
    jac_file: str,
    base_path: str,
    endpoint_profile: str = "full",
    setup_background_services: bool = True,
    transport_kind: str = "testclient"
) -> PreparedInProcessRuntime {
    import from starlette.testclient { TestClient }
    import from jac_scale.plugin { JacCmd }

    if transport_kind != "testclient" {
        raise NotImplementedError(
            "transport_kind='" + str(transport_kind) + "' is not implemented; " + "only 'testclient' (in-process, single serialized worker) is " + "supported today. 'asgi' / 'isolated_worker' are reserved for the " + "execution-isolation choice recorded in #6596 P0-0."
        );
    }

    registered_names = [nm for (nm, _p) in plugin_manager.list_name_plugin()];
    if "scale" not in registered_names {
        plugin_manager.register(JacCmd(), name="scale");
    }

    (base, _) = os.path.split(jac_file);
    base = base or "./";
    mod = base_stem(jac_file);
    os.makedirs(base_path, exist_ok=True);
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
        Jac.jac_import(target=mod, base_path=base, lng="jac");

        server = JacAPIServer(module_name=mod, port=0, base_path=base_path);
        server.load_module();

        _register_endpoint_profile(server, endpoint_profile);

        _um = server.user_manager;
        if _um.get_root_id(Con.GUEST.value) is None {
            _um.create_internal_user(Con.GUEST.value, "__no_password__");
        }
        def _shared_root_id -> (str | None) {
            return _um.get_root_id(Con.GUEST.value);
        }
        Jac.set_shared_root_resolver(_shared_root_id);

        if setup_background_services {
            server.setup_emailer();
            server._setup_scheduler();
            server._setup_events();
        }

        server.server.create_server();

        client = TestClient(server.server.app, raise_server_exceptions=False);
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
        Jac.set_context(prior_ctx);
        mach.close();
        raise;
    }
}
