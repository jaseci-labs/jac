"""The consumer-side instance of a remote walker spawn is built from what the
caller sent plus the provider's reports, never from the wire `result`."""
import from jaclang.server { sv_client }
import from jaclang.server.bridge { BridgeError }

obj GreetStub {
    static has __jac_fields__: list = ["name", "loud"],
        __jac_boundary_types__: dict = {};

    static def _from_wire(d: dict) -> GreetStub {
        inst = object.__new__(GreetStub);
        for (k, v) in d.items() {
            setattr(inst, k, v);
        }
        return inst;
    }
}

test "remote walker keeps the caller's fields and the provider's reports" {
    data = {"ok": True, "data": {"result": {}, "reports": ["hello, ada"]}};
    rg = sv_client.hydrate_walker_envelope(
        data, "notify_service", "Greet", {"name": "ada"}, GreetStub
    );
    assert rg.name == "ada";
    assert rg.loud is None;
    assert rg.reports == ["hello, ada"];
}

test "remote walker with no reports gets an empty list" {
    data = {"ok": True, "data": {"result": {}, "reports": []}};
    rg = sv_client.hydrate_walker_envelope(
        data, "notify_service", "Greet", {"name": "ada"}, GreetStub
    );
    assert rg.reports == [];
}

test "remote walker failure names the spawn" {
    data = {"ok": False, "error": {"message": "boom"}};
    try {
        sv_client.hydrate_walker_envelope(
            data, "notify_service", "Greet", {"name": "ada"}, GreetStub
        );
        assert False , "an error envelope must raise";
    } except BridgeError as e {
        assert "notify_service.Greet" in str(e);
        assert "boom" in str(e);
    }
}
