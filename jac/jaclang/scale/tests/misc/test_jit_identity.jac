import os;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.plugin { JacScalePlugin }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }
import from jaclang.scale.config.config_loader { JacScaleConfig }


obj _AbsentUserStorage {
    has root_id: str | None = None,
        calls: list = [];

    def user_exists_by_id(user_id: str) -> bool {
        return False;
    }

    def get_username(user_id: str) -> str | None {
        return None;
    }

    def get_user_role(user_id: str) -> str | None {
        return None;
    }

    def find_user_by_identity(value: str) -> dict | None {
        return None;
    }

    def ensure_user_by_id(user_id: str) -> str | None {
        self.calls.append(user_id);
        return self.root_id;
    }
}


def _manager(jit: bool, storage: _AbsentUserStorage) -> JacScaleUserManager {
    um = JacScaleUserManager(base_path=tempfile.mkdtemp(), jit_provision=jit);
    um._identity_storage = storage;
    return um;
}


test "a valid token for a locally unknown user is rejected without JIT" {
    storage = _AbsentUserStorage(root_id="root-1");
    um = _manager(False, storage);
    token = um.create_jwt_token("user-from-gateway");
    detail = um.validate_jwt_token_detail(token);
    assert detail["status"] == "unknown_user";
    assert storage.calls == [];
}


test "JIT provisions the user and accepts the token" {
    storage = _AbsentUserStorage(root_id="root-1");
    um = _manager(True, storage);
    token = um.create_jwt_token("user-from-gateway");
    detail = um.validate_jwt_token_detail(token);
    assert detail["status"] == "ok" , detail;
    assert detail["user_id"] == "user-from-gateway";
    assert storage.calls == ["user-from-gateway"];
}


test "JIT that cannot provision still rejects" {
    storage = _AbsentUserStorage();
    um = _manager(True, storage);
    token = um.create_jwt_token("user-from-gateway");
    detail = um.validate_jwt_token_detail(token);
    assert detail["status"] == "unknown_user";
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
        '[project]\nname = "t"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n' + '[scale.microservices.identity]\ngateway_owned = false\n'
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
