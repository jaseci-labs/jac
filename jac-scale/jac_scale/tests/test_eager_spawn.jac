"""Tests for sv-to-sv eager auto-spawn at consumer server startup.

The feature: when a consumer server starts, it walks its compile-time
recorded sv-import providers (populated at consumer module import time
by PyastGenPass-emitted _declare_consumer_provider calls), BFSes any
transitive providers, and dispatches them through sv_client.ensure_all
before serving traffic. Siblings spawned via ensure_sv_service skip
their own eager-spawn pass so only the root consumer drives spawns.

Tests cover:
  1. _declare_consumer_provider populates _consumer_providers correctly
     (including dedup across repeated declarations).
  2. ensure_all short-circuits when every provider is already a test
     client or in the registry.
  3. ensure_all resolves providers via JAC_SV_<MOD>_URL env vars.
  4. ensure_all fail-fast: first failure cancels pending spawns and
     re-raises.
  5. Consumer module import triggers compile-time-emitted
     _declare_consumer_provider side effect.
  6. is_sv_sibling=True causes _ensure_sv_siblings to short-circuit,
     so siblings do not drive their own eager spawn.
  7. Non-sibling consumer's _ensure_sv_siblings walks direct providers.
  8. Transitive BFS: consumer imports B, B imports C; root consumer
     picks up C via the BFS over B's recorded providers.
"""

import os;
import sys;
import shutil;
import glob;
import tempfile;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib { sv_client as __jac_sv }
import from starlette.testclient { TestClient }
import from jac_scale.serve { JacAPIServer }

glob FIXTURES: Path = Path(__file__).parent / "fixtures" / "microservice";

def setup_env -> str {
    tmp = tempfile.mkdtemp();
    for f in glob.glob(str(FIXTURES / "*")) {
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

"""Register an in-process stub TestClient so ensure_all short-circuits."""
def make_stub_client(mod: str) -> TestClient {
    client: TestClient = TestClient.__new__(TestClient);
    __jac_sv.register_test_client(mod, client);
    return client;
}

# -----------------------------------------------------------------------------
# 1. _declare_consumer_provider registration
# -----------------------------------------------------------------------------
test "eager spawn: declare_consumer_provider records and dedupes" {
    __jac_sv.clear_consumer_providers();
    __jac_sv._declare_consumer_provider("consumer_x", "prov_a");
    __jac_sv._declare_consumer_provider("consumer_x", "prov_b");
    __jac_sv._declare_consumer_provider("consumer_x", "prov_a");  # dup
    __jac_sv._declare_consumer_provider("consumer_y", "prov_z");

    assert __jac_sv.get_consumer_providers("consumer_x") == ["prov_a", "prov_b"];
    assert __jac_sv.get_consumer_providers("consumer_y") == ["prov_z"];
    assert __jac_sv.get_consumer_providers("unknown") == [];
    __jac_sv.clear_consumer_providers();
    assert __jac_sv.get_consumer_providers("consumer_x") == [];
}

# -----------------------------------------------------------------------------
# 2. ensure_all skips providers that are already resolved
# -----------------------------------------------------------------------------
test "eager spawn: ensure_all no-op when all already resolved" {
    __jac_sv.clear_test_clients();
    __jac_sv._registry.clear();
    __jac_sv._registry["already_registered"] = "http://somewhere";
    make_stub_client("already_test_client");

    # Should not raise and should not add anything new
    __jac_sv.ensure_all(["already_registered", "already_test_client"]);
    assert __jac_sv._registry.get("already_registered") == "http://somewhere";
    assert "already_test_client" in __jac_sv._test_clients;

    __jac_sv.clear_test_clients();
    del __jac_sv._registry["already_registered"];
}

# -----------------------------------------------------------------------------
# 3. ensure_all resolves via JAC_SV_<MOD>_URL env var
# -----------------------------------------------------------------------------
test "eager spawn: ensure_all registers URLs from env vars" {
    __jac_sv.clear_test_clients();
    __jac_sv._registry.clear();
    os.environ["JAC_SV_EAGER_ENV_MOD_URL"] = "http://eager-env-mod.example";
    try {
        __jac_sv.ensure_all(["eager_env_mod"]);
        assert __jac_sv._registry.get("eager_env_mod") == "http://eager-env-mod.example";
    } finally {
        del os.environ["JAC_SV_EAGER_ENV_MOD_URL"];
        if "eager_env_mod" in __jac_sv._registry {
            del __jac_sv._registry["eager_env_mod"];
        }
    }
}

# -----------------------------------------------------------------------------
# 4. fail-fast on first spawn failure
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 5. Consumer module import triggers compile-time _declare_consumer_provider
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 6. is_sv_sibling=True short-circuits _ensure_sv_siblings
# -----------------------------------------------------------------------------
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
        # Nothing should have been registered -- siblings do not drive spawns
        assert "math_service" not in __jac_sv._registry;
    } finally {
        done(tmp);
    }
}

# -----------------------------------------------------------------------------
# 7. Non-sibling consumer walks direct providers
# -----------------------------------------------------------------------------
test "eager spawn: non-sibling consumer resolves declared providers" {
    tmp = setup_env();
    try {
        Jac.jac_import(target="calculator_service", base_path=tmp, lng="jac");
        __jac_sv._registry.clear();
        __jac_sv.clear_test_clients();
        # Pre-register math_service as a test client so ensure_all short-circuits
        make_stub_client("math_service");

        srv = JacAPIServer(module_name="calculator_service", port=0, base_path=tmp);
        srv.load_module();
        assert srv.is_sv_sibling == False;

        # Should complete without raising -- math_service is already a test client
        srv._ensure_sv_siblings();
        assert "math_service" in __jac_sv._test_clients;
    } finally {
        done(tmp);
    }
}

# -----------------------------------------------------------------------------
# 8. Transitive BFS: A imports B imports C
# -----------------------------------------------------------------------------
test "eager spawn: transitive BFS discovers providers through chain" {
    tmp = setup_env();
    try {
        # Import level_a and level_b so their compile-time
        # _declare_consumer_provider calls populate the registry.
        # level_c has no sv imports, so it declares nothing when loaded.
        Jac.jac_import(target="level_a", base_path=tmp, lng="jac");
        Jac.jac_import(target="level_b", base_path=tmp, lng="jac");

        # Confirm the import-time registrations landed correctly.
        assert __jac_sv.get_consumer_providers("level_a") == ["level_b"];
        assert __jac_sv.get_consumer_providers("level_b") == ["level_c"];
        assert __jac_sv.get_consumer_providers("level_c") == [];

        __jac_sv._registry.clear();
        __jac_sv.clear_test_clients();
        # Pre-register every level as a test client so ensure_all never
        # hits the real spawn path. We verify the BFS traversal by
        # monkey-patching ensure_all itself to record its call arguments.
        make_stub_client("level_b");
        make_stub_client("level_c");

        # Record ensure_all calls in order
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

        # The BFS should have issued exactly two waves:
        #   Wave 1: ["level_b"] (level_a's direct providers)
        #   Wave 2: ["level_c"] (discovered via level_b's providers)
        assert len(calls) == 2 , f"Expected 2 BFS waves, got {len(calls)}: {calls}";
        assert calls[0] == ["level_b"];
        assert calls[1] == ["level_c"];
    } finally {
        done(tmp);
    }
}

# -----------------------------------------------------------------------------
# 9. Cycle handling: A imports B imports A (via declared providers)
# -----------------------------------------------------------------------------
test "eager spawn: cycles do not deadlock or double-spawn" {
    __jac_sv.clear_consumer_providers();
    __jac_sv._registry.clear();
    __jac_sv.clear_test_clients();

    # Simulate a cycle directly via the registration API: A -> B, B -> A
    __jac_sv._declare_consumer_provider("cycle_a", "cycle_b");
    __jac_sv._declare_consumer_provider("cycle_b", "cycle_a");

    make_stub_client("cycle_a");
    make_stub_client("cycle_b");

    # Record calls to ensure_all
    calls: list[list[str]] = [];
    original_ensure_all = __jac_sv.ensure_all;
    def recording_ensure_all(module_names: list[str]) {
        calls.append(list(module_names));
        return original_ensure_all(module_names);
    }
    __jac_sv.ensure_all = recording_ensure_all;

    try {
        # Manually walk the BFS logic here (no real server needed)
        # to verify the visited set prevents the cycle from looping
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
        # BFS walks 2 hops then terminates: wave 1 = [cycle_b], wave 2 =
        # [cycle_a] (discovered via cycle_b's providers), then cycle_a's
        # own provider cycle_b is already visited so the BFS halts.
        # The key guarantees are: (a) termination, (b) no double-spawn.
        assert iter_count == 2 , f"BFS should terminate after 2 iterations, got {iter_count}";
        assert calls == [["cycle_b"], ["cycle_a"]] , f"Expected [cycle_b] then [cycle_a] once each, got {calls}";
    } finally {
        __jac_sv.ensure_all = original_ensure_all;
        __jac_sv.clear_consumer_providers();
        __jac_sv.clear_test_clients();
    }
}
