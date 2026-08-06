import os;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }
import from jaclang.scale.config.config_loader { JacScaleConfig }


# The production topology, in miniature: a "gateway" manager and a "service"
# manager over separate real stores, sharing the fleet JWT config. Users and
# sessions live only in the gateway's store until JIT provisioning runs.
def _gateway_with_user -> tuple {
    gateway = JacScaleUserManager(base_path=tempfile.mkdtemp());
    result = gateway.create_user_with_identities(
        identities=[{"type": "username", "value": "fleet-user"}],
        credential={"type": "password", "password": "pw-12345"}
    );
    assert result.get("user_id") , result;
    return (gateway, result["user_id"]);
}


test "a valid gateway token for a locally unknown user is rejected without JIT" {
    (gateway, user_id) = _gateway_with_user();
    service = JacScaleUserManager(base_path=tempfile.mkdtemp(), jit_provision=False);
    token = gateway.create_jwt_token(user_id);
    detail = service.validate_jwt_token_detail(token);
    assert detail["status"] == "unknown_user" , detail;
    assert service.user_exists(user_id) is False;
}


test "JIT provisions the user once and accepts the token" {
    (gateway, user_id) = _gateway_with_user();
    service = JacScaleUserManager(base_path=tempfile.mkdtemp(), jit_provision=True);
    token = gateway.create_jwt_token(user_id);
    detail = service.validate_jwt_token_detail(token);
    assert detail["status"] == "ok" , detail;
    assert detail["user_id"] == user_id;
    assert service.user_exists(user_id) is True;
    root_id = service.get_root_id(user_id);
    assert root_id;
    # Idempotent: a second request reuses the provisioned record and root.
    detail2 = service.validate_jwt_token_detail(token);
    assert detail2["status"] == "ok" , detail2;
    assert service.get_root_id(user_id) == root_id;
}


test "JIT that cannot provision still rejects" {
    (gateway, user_id) = _gateway_with_user();
    service = JacScaleUserManager(base_path=tempfile.mkdtemp(), jit_provision=True);
    service._identity_storage._store_user(
        {
            "user_id": user_id,
            "status": "deleted",
            "identities": [],
            "credentials": [],
            "root_id": "root-ghost",
            "role": "user",
            "profile": {},
            "created_at": "2026-01-01T00:00:00",
            "updated_at": "2026-01-01T00:00:00"
        }
    );
    token = gateway.create_jwt_token(user_id);
    detail = service.validate_jwt_token_detail(token);
    assert detail["status"] == "unknown_user" , detail;
}


test "fleet service processes get JIT enabled; standalone ones do not" {
    saved = os.environ.pop("JAC_SV_NAME", None);
    try {
        um = JacScalePlugin.get_user_manager(base_path=tempfile.mkdtemp());
        assert um.jit_provision is False;
        os.environ["JAC_SV_NAME"] = "orders_app";
        um2 = JacScalePlugin.get_user_manager(base_path=tempfile.mkdtemp());
        assert um2.jit_provision is True;
    } finally {
        os.environ.pop("JAC_SV_NAME", None);
        if saved is not None {
            os.environ["JAC_SV_NAME"] = saved;
        }
    }
}


test "identity config defaults to gateway_owned and honors an opt-out" {
    tmp = tempfile.mkdtemp();
    Path(tmp, "jac.toml").write_text(
        '[project]\nname = "t"\nversion = "0.0.1"\nentry-point = "main.jac"\n'
    );
    cfg = JacScaleConfig(project_dir=Path(tmp)).get_microservices_config();
    assert cfg["identity"]["gateway_owned"] is True;

    tmp2 = tempfile.mkdtemp();
    Path(tmp2, "jac.toml").write_text(
        '[project]\nname = "t"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n'
            + '[scale.microservices.identity]\ngateway_owned = false\n'
    );
    cfg2 = JacScaleConfig(project_dir=Path(tmp2)).get_microservices_config();
    assert cfg2["identity"]["gateway_owned"] is False;
}


test "a tombstoned user cannot be re-provisioned from a still-valid token" {
    tmp = tempfile.mkdtemp();
    um = JacScaleUserManager(base_path=tmp, jit_provision=True);
    um._identity_storage._store_user(
        {
            "user_id": "ghost",
            "status": "deleted",
            "identities": [],
            "credentials": [],
            "root_id": "root-ghost",
            "role": "user",
            "profile": {},
            "created_at": "2026-01-01T00:00:00",
            "updated_at": "2026-01-01T00:00:00"
        }
    );
    assert um.user_exists("ghost") is False;
    token = um.create_jwt_token("ghost");
    detail = um.validate_jwt_token_detail(token);
    assert detail["status"] == "unknown_user" , detail;
}


test "delete_user leaves a tombstone, not an absence" {
    tmp = tempfile.mkdtemp();
    um = JacScaleUserManager(base_path=tmp, jit_provision=True);
    um._identity_storage._store_user(
        {
            "user_id": "doomed",
            "status": "active",
            "identities": [],
            "credentials": [],
            "root_id": "root-doomed",
            "role": "user",
            "profile": {},
            "created_at": "2026-01-01T00:00:00",
            "updated_at": "2026-01-01T00:00:00"
        }
    );
    result = um.delete_user("doomed");
    assert result.get("message") , result;
    raw = um._identity_storage.get_user_by_id("doomed");
    assert raw is not None and raw.get("status") == "deleted";
    assert um._identity_storage.ensure_user_by_id("doomed") is None;
}


test "tombstoned users disappear from listings" {
    tmp = tempfile.mkdtemp();
    um = JacScaleUserManager(base_path=tmp, jit_provision=True);
    for uid in ["keeper", "goner"] {
        um._identity_storage._store_user(
            {
                "user_id": uid,
                "status": "active",
                "identities": [],
                "credentials": [],
                "root_id": "root-" + uid,
                "role": "user",
                "profile": {},
                "created_at": "2026-01-01T00:00:00",
                "updated_at": "2026-01-01T00:00:00"
            }
        );
    }
    assert {u["user_id"] for u in um.list_all_users()} == {"keeper", "goner"};
    result = um.delete_user("goner");
    assert result.get("message") , result;
    assert {u["user_id"] for u in um.list_all_users()} == {"keeper"};
}
