"""TDD tests for sv-to-sv microservice interop.

Simulates the jac start flow: each module is its own server.
Consumer sv-imported functions should route through the provider's
HTTP endpoints, NOT be called in-process.

Key RED test: we verify that the consumer's sv-imported functions are
HTTP stubs (not the original function objects). This fails until the
compiler generates proper HTTP client stubs for sv-to-sv imports.
"""

import os;
import sys;
import shutil;
import glob;
import tempfile;
import from pathlib { Path }
import from typing { Any }
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib { sv_client as __jac_sv }
import from starlette.testclient { TestClient }
import from jac_scale.serve { JacAPIServer }

glob FIXTURES: Path = Path(__file__).parent / "fixtures" / "microservice";

def make_server(mod: str, tmp: str) -> TestClient {
    if mod in Jac.loaded_modules {
        del Jac.loaded_modules[mod];
    }
    if mod in sys.modules {
        del sys.modules[mod];
    }
    Jac.jac_import(target=mod, base_path=tmp, lng="jac");
    srv = JacAPIServer(module_name=mod, port=0, base_path=tmp);
    srv.load_module();
    srv.register_health_endpoint();
    srv.register_walkers_endpoints();
    srv.register_functions_endpoints();
    srv.register_auth_endpoints();
    srv.user_manager.create_internal_user(Con.GUEST.value, '__no_password__');
    srv.server.create_server();
    client = TestClient(srv.server.app, raise_server_exceptions=False);
    __jac_sv.register_test_client(mod, client);
    return client;
}

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
    return tmp;
}

def xd(resp: Any) -> Any {
    j = resp.json();
    if isinstance(j, dict) and j.get("ok") and j.get("data") is not None {
        return j["data"];
    }
    return j;
}

def done(tmp: str) {
    shutil.rmtree(tmp, ignore_errors=True);
}

# =============================================================================
# RED: sv import should generate HTTP stubs, not share module references
# =============================================================================
test "sv-to-sv: sv import does not load provider into process" {
    # sv import should generate HTTP stubs, NOT import the provider module.
    # Loading order_service should NOT pull inventory_service into sys.modules.
    tmp = setup_env();
    try {
        # Ensure provider is not loaded
        if "inventory_service" in sys.modules {
            del sys.modules["inventory_service"];
        }
        if "inventory_service" in Jac.loaded_modules {
            del Jac.loaded_modules["inventory_service"];
        }
        # Load ONLY the consumer
        cons = make_server("order_service", tmp);
        # RED: sv import today loads the provider in-process
        assert "inventory_service" not in sys.modules;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv import does not load math provider into process" {
    tmp = setup_env();
    try {
        if "math_service" in sys.modules {
            del sys.modules["math_service"];
        }
        if "math_service" in Jac.loaded_modules {
            del Jac.loaded_modules["math_service"];
        }
        cons = make_server("calculator_service", tmp);
        assert "math_service" not in sys.modules;
    } finally {
        done(tmp);
    }
}

# =============================================================================
# End-to-end: verify behavior AND that provider isn't loaded in consumer
# =============================================================================
test "sv-to-sv: consumer creates order via provider" {
    tmp = setup_env();
    try {
        prov = make_server("inventory_service", tmp);
        cons = make_server("order_service", tmp);
        prov.post(
            "/function/add_product",
            json={"sku": "W", "name": "Widget", "quantity": 50, "price": 9.99}
        );
        r = xd(
            cons.post(
                "/function/create_order", json={"items": [{"sku": "W", "quantity": 2}]}
            )
        )["result"];
        assert r["success"] is True;
        assert abs(r["total"] - 19.98) < 0.01;
        # RED: consumer should not share provider's module object
        ord_mod = Jac.loaded_modules["order_service"];
        inv_mod = sys.modules.get("inventory_service");
        assert inv_mod is None or ord_mod.check_stock is not inv_mod.check_stock;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: error propagates across boundary" {
    tmp = setup_env();
    try {
        prov = make_server("inventory_service", tmp);
        cons = make_server("order_service", tmp);
        r = xd(
            cons.post(
                "/function/create_order",
                json={"items": [{"sku": "NOPE", "quantity": 1}]}
            )
        )["result"];
        assert r["success"] is False;
        ord_mod = Jac.loaded_modules["order_service"];
        inv_mod = sys.modules.get("inventory_service");
        assert inv_mod is None or ord_mod.check_stock is not inv_mod.check_stock;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: typed objects serialize across boundary" {
    tmp = setup_env();
    try {
        prov = make_server("math_service", tmp);
        cons = make_server("calculator_service", tmp);
        r = xd(cons.post("/function/safe_divide", json={"a": 10.0, "b": 0.0}))[
            "result"
        ];
        assert r["error"] == "division by zero";
        assert r["result"] is None;
        calc_mod = Jac.loaded_modules["calculator_service"];
        math_mod = sys.modules.get("math_service");
        assert math_mod is None or calc_mod.add is not math_mod.add;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: walker routes through provider" {
    tmp = setup_env();
    try {
        prov = make_server("inventory_service", tmp);
        cons = make_server("order_service", tmp);
        prov.post(
            "/function/add_product",
            json={"sku": "B", "name": "Bolt", "quantity": 500, "price": 0.1}
        );
        rpt = xd(
            cons.post(
                "/walker/CheckOrderFeasibility", json={"sku": "B", "quantity": 100}
            )
        )["reports"][0];
        assert rpt["feasible"] is True;
        assert rpt["available"] == 500;
        ord_mod = Jac.loaded_modules["order_service"];
        inv_mod = sys.modules.get("inventory_service");
        assert inv_mod is None or ord_mod.check_stock is not inv_mod.check_stock;
    } finally {
        done(tmp);
    }
}
