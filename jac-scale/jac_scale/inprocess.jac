"""Shared "no-serve startup" seam for an in-process jac-scale runtime (#6685).

`JacAPIServerCore.start()` ends in `run_server()` (binds a real socket). Two
callers instead want the SAME server prepared but driven in-process over a
Starlette `TestClient` (no socket, no remote server):

* jac-scale's own `ScaleTestClient` (its test suite), and
* the Jac-native desktop host's `inprocess_dispatch.boot()` (#6596), which runs
  a `cl` -> `sv` call inside the embedded CPython instead of over HTTP.

Both used to hand-copy the genuinely duplicated, drift-prone core -- module load
+ server construction + endpoint registration + guest user + transport -- and
they had already drifted (the desktop copy leaned on postinit's LAZY shared-root
resolver by construction-order luck; `start()` installs an EAGER one). This seam
owns that core in ONE place, parameterized by:

* `endpoint_profile` -- which endpoint subset to register (`"desktop"` =
  health/auth/walkers/functions; `"test"` = the set ScaleTestClient drives;
  `"full"` = everything `start()` registers, minus the socket bind).
* `setup_background_services` -- whether to wire emailer/scheduler/events. The
  desktop and test paths skip these (out of scope for in-process dispatch);
  `"full"` callers default them on.
* `transport_kind` -- the execution-isolation boundary recorded in #6596 P0-0.
  Only `"testclient"` (in-process, single serialized worker) is implemented;
  `"asgi"` and `"isolated_worker"` are reserved so the choice lives in the seam
  API rather than being an unspoken "testclient + same process" default.

It deliberately does NOT do what `start()` does beyond preparation (HMR
middleware, client-bundle build, port-finding, banner, `run_server`); those are
serving concerns, not preparation.
"""

import os;
import sys;

import from jaclang { JacRuntime as Jac, plugin_manager }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.ext_registry { base_stem }
import from jac_scale.serve { JacAPIServer }


"""A prepared, non-serving in-process jac-scale runtime.

Owns the prepared `server` (a `JacAPIServer` whose endpoints are registered but
whose socket is never bound) and the `client` transport that drives it in
process. `transport_kind` records which execution-isolation boundary the seam
built (P0-0). Call `close()` on shutdown to tear the transport down.
"""
obj PreparedInProcessRuntime {
    has server: any,
        transport_kind: str,
        client: any | None = None,
        _prior_ctx: any = None;

    """Tear down the transport and drop the server reference.

    For the TestClient transport this closes the client (and, once the transport
    is context-managed per P0-B, exits its anyio portal). Idempotent."""
    def close {
        if self.client is not None {
            self.client.close();
            self.client = None;
        }
        # Clear the shared-root resolver so any surviving slow walker (that
        # outlasted the shutdown join timeout) doesn't call into the dead
        # user_manager via the stale closure after server is dropped.
        Jac.set_shared_root_resolver(None);
        self.server = None;
        # Restore the caller's Jac context that was active before prepare_inprocess_runtime().
        # Without this, sequential runtimes (test re-use, desktop re-boot) leave the
        # process permanently in the last runtime's machine context.
        Jac.set_context(self._prior_ctx);
        self._prior_ctx = None;
    }
}


"""Register the endpoint subset named by `profile` onto `server`.

Order is preserved per profile to keep route resolution identical to what the
callers registered by hand before this seam existed."""
def _register_endpoint_profile(server: any, profile: str) {
    if profile == "desktop" {
        # What a desktop `cl` client drives: health, auth (login / refresh /
        # sso), and the walker + function dispatch (#6596).
        server.register_health_endpoint();
        server.register_auth_endpoints();
        server.register_walkers_endpoints();
        server.register_functions_endpoints();
    } elif profile == "test" {
        # The set ScaleTestClient._initialize() registered before #6685 (same
        # order, including workloads -- not an expansion over the old test path).
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
        # Everything a real `start()` registers (minus the socket bind).
        # TODO(jaseci-labs/jaseci#6797): _register_endpoints() is a private method;
        # a public prepare_server() facade on JacAPIServerCore should own this.
        server._register_endpoints();
    } else {
        raise ValueError(
            "unknown endpoint_profile '" + str(profile) + "' (expected 'desktop', 'test', or 'full')"
        );
    }
}


"""Prepare an in-process jac-scale runtime for `jac_file`'s module (no socket).

`jac_file` is the user's `.jac` entry point; `base_path` is the on-disk graph /
persistence dir (created if absent). Loads the module into a fresh Jac context,
constructs a `port=0` `JacAPIServer`, registers the `endpoint_profile` subset,
creates the guest user + installs the shared-root resolver, optionally wires
background services, and builds the `transport_kind` transport. Returns the owned
`PreparedInProcessRuntime`.

Replaces the core that `ScaleTestClient._initialize()` and the desktop
`inprocess_dispatch.boot()` each hand-copied (and had drifted on)."""
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

    # jac-scale is a jaclang PLUGIN. A pip-installed wheel registers its entry
    # point ("scale") automatically, but a source/staged runtime (e.g. the
    # desktop bundle) does not -- without it the server falls back to jaclang's
    # base UserManager (no create_internal_user / sso_initiate) and boot dies.
    # Idempotent: guarded on the entry-point name so a second prepare in the same
    # process (desktop tests + ScaleTestClient) is a no-op rather than a duplicate
    # hook registration. (Previously an out-of-band try/except in desktop boot().)
    registered_names = [nm for (nm, _p) in plugin_manager.list_name_plugin()];
    if "scale" not in registered_names {
        plugin_manager.register(JacCmd(), name="scale");
    }

    # Load the user's module into a fresh Jac context, evicting any same-named
    # module a prior import (e.g. the test runner) left behind.
    (base, _) = os.path.split(jac_file);
    base = base or "./";
    mod = base_stem(jac_file);
    os.makedirs(base_path, exist_ok=True);
    Jac.set_base_path(base_path);
    # Capture the caller's context so it can be restored both on failure (except
    # path below) and on clean close() (stored in PreparedInProcessRuntime._prior_ctx).
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

        # port=0 => in-process mode: postinit builds a bare JFastApiServer and never
        # binds a socket.
        server = JacAPIServer(module_name=mod, port=0, base_path=base_path);
        server.load_module();

        _register_endpoint_profile(server, endpoint_profile);

        # Create the guest user, then install the shared-root resolver EAGERLY -- the
        # guest now exists, so the resolver just maps it to its root id (the same
        # closure `start()` installs). The in-process callers previously relied on
        # postinit's LAZY resolver by construction-order luck; make the choice
        # explicit here so `root.shared` does not hinge on import order.
        #
        # Idempotent: a persisted store (e.g. the desktop's ~/.jac/desktop/graph
        # across launches) already has the guest, in which case an unguarded
        # create_internal_user returns an IDENTITY_TAKEN error dict we'd silently
        # ignore. Guard on the existing root id so the intent is explicit and the
        # call survives a future storage layer that raises on duplicate.
        _um = server.user_manager;
        if _um.get_root_id(Con.GUEST.value) is None {
            _um.create_internal_user(Con.GUEST.value, "__no_password__");
        }
        def _shared_root_id -> (str | None) {
            return _um.get_root_id(Con.GUEST.value);
        }
        Jac.set_shared_root_resolver(_shared_root_id);

        if setup_background_services {
            # The serving path's side services. Skipped by the desktop/test profiles
            # (out of scope for in-process walker/function dispatch); on by default
            # for a "full" non-serving runtime that wants them.
            # NOTE: the seam depends on these JacAPIServer hooks (three are underscore-
            # private today). A future refactor should fold them behind a single public
            # prepare_server(profile, background_services) facade on JacAPIServerCore.
            # TODO: tracked in jaseci-labs/jaseci#6797.
            server.setup_emailer();
            server._setup_scheduler();
            server._setup_events();
        }

        # Compile the registered JEndPoints into FastAPI routes.
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
