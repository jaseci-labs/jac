import os;
import sys;
import shutil;
import glob;
import tempfile;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.server { sv_client as __jac_sv }
import from jaclang.server.bridge { BridgeUnavailable }
import from jaclang.testing.testkit { ServingTestClient as TestClient }
import from jaclang.server.server { JacAPIServer }

glob FIXTURES: Path = Path(__file__).parent.parent / "fixtures" / "microservice";

def setup_env -> str {
    tmp = tempfile.mkdtemp();
    for f in `glob.`glob(str(FIXTURES / "*")) {
        if Path(f).is_file() {
            shutil.copy2(f, Path(tmp) / Path(f).name);
        }
    }
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    __jac_sv.clear_test_clients();
    __jac_sv.clear_consumer_providers();
    for mod_name in [
        "level_a",
        "level_b",
        "level_c",
        "math_service",
        "calculator_service"
    ] {
        if mod_name in Jac.loaded_modules {
            del Jac.loaded_modules[mod_name];
        }
        if mod_name in sys.modules {
            del sys.modules[mod_name];
        }
    }
    return tmp;
}

def done(tmp: str) {
    shutil.rmtree(tmp, ignore_errors=True);
}

def make_stub_client(mod: str) -> TestClient {
    client: TestClient = TestClient.__new__(TestClient);
    __jac_sv.register_test_client(mod, client);
    return client;
}

test "eager spawn: declare_consumer_provider records and dedupes" {
    __jac_sv.clear_consumer_providers();
    __jac_sv._declare_consumer_provider("consumer_x", "prov_a");
    __jac_sv._declare_consumer_provider("consumer_x", "prov_b");
    __jac_sv._declare_consumer_provider("consumer_x", "prov_a");
    __jac_sv._declare_consumer_provider("consumer_y", "prov_z");

    assert __jac_sv.get_consumer_providers("consumer_x") == ["prov_a", "prov_b"];
    assert __jac_sv.get_consumer_providers("consumer_y") == ["prov_z"];
    assert __jac_sv.get_consumer_providers("unknown") == [];
    __jac_sv.clear_consumer_providers();
    assert __jac_sv.get_consumer_providers("consumer_x") == [];
}

test "eager spawn: ensure_all no-op when all already resolved" {
    __jac_sv.clear_test_clients();
    __jac_sv._registry.clear();
    __jac_sv._registry["already_registered"] = "http://somewhere";
    make_stub_client("already_test_client");

    __jac_sv.ensure_all(["already_registered", "already_test_client"]);
    assert __jac_sv._registry.get("already_registered") == "http://somewhere";
    assert "already_test_client" in __jac_sv._test_clients;

    __jac_sv.clear_test_clients();
    del __jac_sv._registry["already_registered"];
}

test "eager spawn: ensure_all registers URLs from env vars" {
    __jac_sv.clear_test_clients();
    __jac_sv._registry.clear();
    os.environ["JAC_APP_EAGER_ENV_MOD_URL"] = "http://eager-env-mod.example";
    try {
        __jac_sv.ensure_all(["eager_env_mod"]);
        assert __jac_sv._registry.get("eager_env_mod")
            == "http://eager-env-mod.example";
    } finally {
        del os.environ["JAC_APP_EAGER_ENV_MOD_URL"];
        if "eager_env_mod" in __jac_sv._registry {
            del __jac_sv._registry["eager_env_mod"];
        }
    }
}

test "eager spawn: ensure_all fail-fast re-raises first error" {
    __jac_sv.clear_test_clients();
    __jac_sv._registry.clear();
    raised: bool = False;
    try {
        __jac_sv.ensure_all(["nonexistent_fail_fast_mod"]);
    } except Exception {
        raised = True;
    }
    assert raised;
}

test "eager spawn: consumer module import registers its providers" {
    tmp = setup_env();
    try {
        Jac.jac_import(target="calculator_service", base_path=tmp, lng="jac");
        providers = __jac_sv.get_consumer_providers("calculator_service");
        assert "math_service" in providers;
    } finally {
        done(tmp);
    }
}

test "eager spawn: sibling flag skips the eager spawn pass" {
    tmp = setup_env();
    try {
        Jac.jac_import(target="calculator_service", base_path=tmp, lng="jac");
        __jac_sv._registry.clear();
        __jac_sv.clear_test_clients();

        srv = JacAPIServer(
            module_name="calculator_service", port=0, base_path=tmp, is_sv_sibling=True
        );
        srv.load_module();
        srv._ensure_sv_siblings();

        assert "math_service" not in __jac_sv._registry;
    } finally {
        done(tmp);
    }
}

test "eager spawn: non-sibling consumer resolves declared providers" {
    tmp = setup_env();
    try {
        Jac.jac_import(target="calculator_service", base_path=tmp, lng="jac");
        __jac_sv._registry.clear();
        __jac_sv.clear_test_clients();

        make_stub_client("math_service");

        srv = JacAPIServer(module_name="calculator_service", port=0, base_path=tmp);
        srv.load_module();
        assert srv.is_sv_sibling == False;

        srv._ensure_sv_siblings();
        assert "math_service" in __jac_sv._test_clients;
    } finally {
        done(tmp);
    }
}

test "eager spawn: transitive BFS discovers providers through chain" {
    tmp = setup_env();
    try {
        Jac.jac_import(target="level_a", base_path=tmp, lng="jac");
        Jac.jac_import(target="level_b", base_path=tmp, lng="jac");

        assert __jac_sv.get_consumer_providers("level_a") == ["level_b"];
        assert __jac_sv.get_consumer_providers("level_b") == ["level_c"];
        assert __jac_sv.get_consumer_providers("level_c") == [];

        __jac_sv._registry.clear();
        __jac_sv.clear_test_clients();

        make_stub_client("level_b");
        make_stub_client("level_c");

        calls: list[list[str]] = [];
        original_ensure_all = __jac_sv.ensure_all;
        def recording_ensure_all(module_names: list[str]) {
            calls.append(list(module_names));
            return original_ensure_all(module_names);
        }
        __jac_sv.ensure_all = recording_ensure_all;
        try {
            srv = JacAPIServer(module_name="level_a", port=0, base_path=tmp);
            srv.load_module();
            srv._ensure_sv_siblings();
        } finally {
            __jac_sv.ensure_all = original_ensure_all;
        }

        assert len(calls) == 2 , f"Expected 2 BFS waves, got {len(calls)}: {calls}";
        assert calls[0] == ["level_b"];
        assert calls[1] == ["level_c"];
    } finally {
        done(tmp);
    }
}

test "eager spawn: cycles do not deadlock or double-spawn" {
    __jac_sv.clear_consumer_providers();
    __jac_sv._registry.clear();
    __jac_sv.clear_test_clients();

    __jac_sv._declare_consumer_provider("cycle_a", "cycle_b");
    __jac_sv._declare_consumer_provider("cycle_b", "cycle_a");

    make_stub_client("cycle_a");
    make_stub_client("cycle_b");

    calls: list[list[str]] = [];
    original_ensure_all = __jac_sv.ensure_all;
    def recording_ensure_all(module_names: list[str]) {
        calls.append(list(module_names));
        return original_ensure_all(module_names);
    }
    __jac_sv.ensure_all = recording_ensure_all;

    try {
        visited: set[str] = set();
        frontier: list[str] = __jac_sv.get_consumer_providers("cycle_a");
        max_iterations = 10;
        iter_count = 0;
        while frontier and iter_count < max_iterations {
            iter_count += 1;
            wave: list[str] = [
                p
                for p in frontier
                if p not in visited
            ];
            if not wave {
                break;
            }
            for p in wave {
                visited.add(p);
            }
            __jac_sv.ensure_all(wave);
            next_frontier: list[str] = [];
            for provider in wave {
                for transitive in __jac_sv.get_consumer_providers(provider) {
                    if transitive not in visited {
                        next_frontier.append(transitive);
                    }
                }
            }
            frontier = next_frontier;
        }

        assert iter_count == 2 , f"BFS should terminate after 2 iterations, got {iter_count}";
        assert calls == [["cycle_b"], ["cycle_a"]] , f"Expected [cycle_b] then [cycle_a] once each, got {calls}";
    } finally {
        __jac_sv.ensure_all = original_ensure_all;
        __jac_sv.clear_consumer_providers();
        __jac_sv.clear_test_clients();
    }
}


# Peer URL resolution semantics. peer_url_env_key is the single definition of
# the variable name that carries a peer's URL, shared by the writers (the k8s
# manifest builder, the local process manager) and the readers, so the key
# format is asserted as a literal rather than through the helper.

glob _PROBE: str = "peer_url_probe";


def _probe_env_restore(saved: str | None) {
    key = __jac_sv.peer_url_env_key(_PROBE);
    if saved is None {
        os.environ.pop(key, None);
    } else {
        os.environ[key] = saved;
    }
    __jac_sv.unregister(_PROBE);
}


# Kubernetes names are RFC1123-safe, so a peer named orders_app is served by
# orders-app-service. The env key keeps the raw name, and a reader that rebuilt
# it from the Kubernetes name would look up the wrong variable.
test "peer url: the env key keeps the raw module name" {
    assert __jac_sv.peer_url_env_key("orders_app") == "JAC_APP_ORDERS_APP_URL";
    assert __jac_sv.peer_url_env_key("main") == "JAC_APP_MAIN_URL";
}


test "peer url: unset, blank and whitespace all read as absent" {
    key = __jac_sv.peer_url_env_key(_PROBE);
    saved = os.environ.get(key);
    try {
        os.environ.pop(key, None);
        assert __jac_sv.peer_url_from_env(_PROBE) == "";

        os.environ[key] = "";
        assert __jac_sv.peer_url_from_env(_PROBE) == "";

        os.environ[key] = "   ";
        assert __jac_sv.peer_url_from_env(_PROBE) == "";

        os.environ[key] = " http://peer.invalid ";
        assert __jac_sv.peer_url_from_env(_PROBE) == "http://peer.invalid";
    } finally {
        _probe_env_restore(saved);
    }
}


test "peer url: an in-process registration wins over the env" {
    key = __jac_sv.peer_url_env_key(_PROBE);
    saved = os.environ.get(key);
    try {
        os.environ[key] = "http://from-env.invalid";
        __jac_sv.register(_PROBE, "http://from-registry.invalid");

        assert __jac_sv.resolve_url(_PROBE) == "http://from-registry.invalid";
    } finally {
        _probe_env_restore(saved);
    }
}


test "peer url: the env is used when nothing is registered" {
    key = __jac_sv.peer_url_env_key(_PROBE);
    saved = os.environ.get(key);
    try {
        __jac_sv.unregister(_PROBE);
        os.environ[key] = "http://from-env.invalid";

        assert __jac_sv.resolve_url(_PROBE) == "http://from-env.invalid";
    } finally {
        _probe_env_restore(saved);
    }
}


# Previously any value counted as present, so a blank one resolved to "" and the
# caller failed later with no indication of where the empty URL came from. The
# unresolved peer surfaces as the bridge family's BridgeUnavailable.
test "peer url: a blank env value raises instead of resolving to an empty URL" {
    key = __jac_sv.peer_url_env_key(_PROBE);
    saved = os.environ.get(key);
    try {
        __jac_sv.unregister(_PROBE);
        os.environ[key] = "";

        raised = "";
        try {
            __jac_sv.resolve_url(_PROBE);
        } except BridgeUnavailable as err {
            raised = str(err);
        }

        assert raised , "a blank override resolved instead of raising";
        assert key in raised , (
            f"the error should name the variable to set, got: {raised}"
        );
    } finally {
        _probe_env_restore(saved);
    }
}


# _ensure_available registers what it resolves, so a blank value must not become
# a registration or every later lookup would return the empty URL from cache.
test "peer url: a blank env value is never registered" {
    key = __jac_sv.peer_url_env_key(_PROBE);
    saved = os.environ.get(key);
    try {
        __jac_sv.unregister(_PROBE);
        os.environ[key] = "  ";

        try {
            __jac_sv._ensure_available(_PROBE);
        } except Exception {}

        assert _PROBE not in __jac_sv._registry , (
            "a blank override was cached as a registration"
        );
    } finally {
        _probe_env_restore(saved);
    }
}
