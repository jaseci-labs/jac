"""The consumer-side instance of a remote walker spawn is rebuilt from the
provider's `result` (the executed walker, its fields as the walk left them)
with the provider's `reports` attached, through the stub class the compiler
generates for a real `sv import`, so boundary-typed values inside both come
back as their stub types."""
import os;
import sys;
import types;
import from jaclang.server { sv_client }
import from jaclang.server.bridge { BridgeError }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT }

glob CONSUMER = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "backends",
         "es",
         "fixtures",
         "sv_relative_consumer.jac"
     );

def generated_stubs -> dict {
    py_mod = JacProgram().compile(CONSUMER).gen.py_ast[0];
    mod = types.ModuleType("sv_relative_consumer_stubs");
    sys.modules[mod.__name__] = mod;
    exec(compile(py_mod, "<sv_relative_consumer>", "exec"), mod.__dict__);
    return mod.__dict__;
}

def ok_envelope(result: dict, reports: list) -> dict {
    return {"ok": True, "data": {"result": result, "reports": reports}};
}

test "a remote walker carries the fields its walk left and its typed reports" {
    stubs = generated_stubs();
    Analyze = stubs["Analyze"];
    AnalyticsReport = stubs["AnalyticsReport"];
    rg = sv_client.hydrate_walker_envelope(
        ok_envelope(
            {"_jac_type": "Analyze", "_jac_archetype": "walker", "count": 7},
            [{"_jac_type": "AnalyticsReport", "count": 7, "label": "walker-analyzed"}]
        ),
        "sv_relative_provider",
        "Analyze",
        Analyze
    );
    assert isinstance(rg, Analyze);
    assert rg.count == 7;
    assert isinstance(rg.reports[0], AnalyticsReport);
    assert rg.reports[0].label == "walker-analyzed";
}

test "a walker envelope without reports hydrates with an empty list" {
    Analyze = generated_stubs()["Analyze"];
    rg = sv_client.hydrate_walker_envelope(
        {"ok": True, "data": {"result": {"count": 1}}},
        "sv_relative_provider",
        "Analyze",
        Analyze
    );
    assert rg.count == 1;
    assert rg.reports == [];
}

test "with no stub class the wire payload comes back as is" {
    payload = sv_client.hydrate_walker_envelope(
        ok_envelope({"count": 1}, ["raw"]), "svc", "Ping", None
    );
    assert payload == {"result": {"count": 1}, "reports": ["raw"]};
}

test "an error envelope names the spawn" {
    try {
        sv_client.hydrate_walker_envelope(
            {"ok": False, "error": {"message": "boom"}}, "svc", "Ping", None
        );
        assert False , "an error envelope must raise";
    } except BridgeError as e {
        assert "bridge to 'svc.Ping' failed: boom" == str(e);
    }
}

test "a function envelope yields its result and names the call on failure" {
    assert sv_client.function_result(
        {"ok": True, "data": {"result": 42, "reports": []}}, "svc", "f"
    )
        == 42;
    try {
        sv_client.function_result(
            {"ok": False, "error": {"message": "nope"}}, "svc", "f"
        );
        assert False , "an error envelope must raise";
    } except BridgeError as e {
        assert "bridge to 'svc.f' failed: nope" == str(e);
    }
}
