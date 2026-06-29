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
import from jac_scale.server.serve { JacAPIServer }

glob FIXTURES: Path = Path(__file__).parent.parent / "fixtures" / "microservice";

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

def xd(resp: any) -> any {
    j = resp.json();
    if isinstance(j, dict) and j.get("ok") and j.get("data") is not None {
        return j["data"];
    }
    return j;
}

def done(tmp: str) {
    shutil.rmtree(tmp, ignore_errors=True);
}

test "sv-to-sv: sv import does not load provider into process" {
    tmp = setup_env();
    try {
        if "inventory_service" in sys.modules {
            del sys.modules["inventory_service"];
        }
        if "inventory_service" in Jac.loaded_modules {
            del Jac.loaded_modules["inventory_service"];
        }

        cons = make_server("order_service", tmp);

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

test "sv-to-sv: typed archetype return rehydrates for attribute access" {
    tmp = setup_env();
    try {
        cons = make_server("calculator_service", tmp);
        prov = make_server("math_service", tmp);
        r = xd(cons.post("/function/describe_divide", json={"a": 6.0, "b": 2.0}))[
            "result"
        ];

        assert r["value"] == 3.0;
        assert r["error"] == "";
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

test "sv-to-sv: sv-imported walker round-trips report and fields" {
    tmp = setup_env();
    try {
        prov = make_server("notify_service", tmp);
        cons = make_server("dispatcher_service", tmp);
        rpt = xd(cons.post("/walker/TriggerGreet", json={"who": "world"}))["reports"][
            0
        ];
        assert rpt == "hello, world";

        rpt2 = xd(cons.post("/function/greet_via_walker", json={"who": "ada"}))[
            "result"
        ];
        assert rpt2 == "hello, ada";
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv-imported walker preserves boundary type in reports" {
    tmp = setup_env();
    try {
        prov = make_server("notify_service", tmp);
        cons = make_server("dispatcher_service", tmp);
        rpt = xd(
            cons.post("/walker/Announce", json={"channel": "ops", "subject": "rollout"})
        )["reports"][0];
        assert rpt["channel"] == "ops";
        assert rpt["delivered"] is True;
        assert rpt["message"] == "[ops] rollout";
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv-imported walker does not load provider in-process" {
    tmp = setup_env();
    try {
        if "notify_service" in sys.modules {
            del sys.modules["notify_service"];
        }
        if "notify_service" in Jac.loaded_modules {
            del Jac.loaded_modules["notify_service"];
        }
        cons = make_server("dispatcher_service", tmp);

        disp_mod = Jac.loaded_modules["dispatcher_service"];
        notify_mod = sys.modules.get("notify_service");
        assert notify_mod is None or disp_mod.Greet is not notify_mod.Greet;
    } finally {
        done(tmp);
    }
}
