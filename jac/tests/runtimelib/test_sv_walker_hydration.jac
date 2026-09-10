"""The consumer-side instance of a remote walker spawn is built from what the
caller sent, the provider's literal defaults, and the provider's reports; the
wire `result` of a walker is empty and never consulted. The stub class under
test is the one the compiler generates for a real `sv import`."""
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

def ok_envelope(reports: list) -> dict {
    return {"ok": True, "data": {"result": {}, "reports": reports}};
}

test "remote walker keeps the caller's fields and the provider's reports" {
    Analyze = generated_stubs()["Analyze"];
    rg = sv_client.hydrate_walker_envelope(
        ok_envelope(["analyzed"]),
        "sv_relative_provider",
        "Analyze",
        {"count": 3},
        Analyze
    );
    assert rg.count == 3;
    assert rg.reports == ["analyzed"];
    assert isinstance(rg, Analyze);
}

test "omitted fields take the provider's literal defaults" {
    Tally = generated_stubs()["Tally"];
    rg = sv_client.hydrate_walker_envelope(
        ok_envelope([3]), "sv_relative_provider", "Tally", {"label": "mine"}, Tally
    );
    assert rg.count == 3;
    assert rg.label == "mine";
    assert rg.reports == [3];
}

test "omitted container defaults are not shared between instances" {
    Tally = generated_stubs()["Tally"];
    first = sv_client.hydrate_walker_envelope(
        ok_envelope([]), "sv_relative_provider", "Tally", {}, Tally
    );
    second = sv_client.hydrate_walker_envelope(
        ok_envelope([]), "sv_relative_provider", "Tally", {}, Tally
    );
    first.tags.append("x");
    assert second.tags == [];
    assert Tally.__jac_field_defaults__["tags"] == [];
}

test "the instance does not alias the caller's mutable arguments" {
    Analyze = generated_stubs()["Analyze"];
    sent = {"count": [1, 2]};
    rg = sv_client.hydrate_walker_envelope(
        ok_envelope([]), "sv_relative_provider", "Analyze", sent, Analyze
    );
    rg.count.append(3);
    assert sent["count"] == [1, 2];
    assert rg.reports == [];
}

test "with no stub class the wire payload comes back as is" {
    payload = sv_client.hydrate_walker_envelope(
        ok_envelope(["raw"]), "svc", "Ping", {}, None
    );
    assert payload == {"result": {}, "reports": ["raw"]};
}

test "an error envelope names the spawn" {
    try {
        sv_client.hydrate_walker_envelope(
            {"ok": False, "error": {"message": "boom"}}, "svc", "Ping", {}, None
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
