"""A fleet service must accept a session the gateway minted.

The gateway serves /user/register and /user/login, so users and sessions live
in its store. A service receiving that token had no local record for the
subject and answered unknown_user, so every authenticated walker on every
non-gateway service returned 401. These drive the real user manager against a
real embedded Postgres.
"""

import os;
import uuid;
import from datetime { UTC, datetime, timedelta }
import from jaclang.runtimelib.serving.authcrypt { jwt_encode }
import from jaclang.scale.config.config_loader { normalize_microservices_config }
import from jaclang.scale.identity.user_manager {
    JWT_ALGORITHM,
    JWT_SECRET,
    JacScaleUserManager
}

glob _SV_ENV: str = "JAC_SV_NAME";


"""A session token of the shape the gateway mints, for a user no service knows."""
def _gateway_token(user_id: str) -> str {
    expires = datetime.now(UTC) + timedelta(days=1);
    return jwt_encode(
        {"sub": user_id, "exp": expires}, JWT_SECRET, algorithm=JWT_ALGORITHM
    );
}


"""A manager built as the given process type, or None if Postgres is absent."""
def _manager(sv_name: str) -> (JacScaleUserManager | None) {
    previous = os.environ.get(_SV_ENV);
    if sv_name {
        os.environ[_SV_ENV] = sv_name;
    } elif _SV_ENV in os.environ {
        del os.environ[_SV_ENV];
    }
    try {
        return JacScaleUserManager(base_path=".");
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    } finally {
        if previous is None {
            os.environ.pop(_SV_ENV, None);
        } else {
            os.environ[_SV_ENV] = previous;
        }
    }
}


test "a fleet service accepts a gateway token and provisions the user once" {
    manager = _manager("orders_app");
    if manager is None {
        return;
    }
    user_id = str(uuid.uuid4());
    assert manager.user_exists(user_id) is False;

    detail = manager.validate_jwt_token_detail(_gateway_token(user_id));
    assert detail["status"] == "ok" , f"expected ok, got {detail}";
    assert detail["user_id"] == user_id;
    assert manager.user_exists(user_id) is True;

    root_id = manager.get_root_id(user_id);
    assert root_id;

    again = manager.validate_jwt_token_detail(_gateway_token(user_id));
    assert again["status"] == "ok";
    assert manager.get_root_id(user_id) == root_id , "provisioning must be idempotent";
}


test "the gateway process itself still rejects a subject it does not know" {
    manager = _manager("__gateway__");
    if manager is None {
        return;
    }
    detail = manager.validate_jwt_token_detail(_gateway_token(str(uuid.uuid4())));
    assert detail["status"] == "unknown_user";
    assert detail["user_id"] is None;
}


test "a single-process server rejects a subject it does not know" {
    manager = _manager("");
    if manager is None {
        return;
    }
    detail = manager.validate_jwt_token_detail(_gateway_token(str(uuid.uuid4())));
    assert detail["status"] == "unknown_user";
}


test "an expired gateway token is never provisioned into existence" {
    manager = _manager("orders_app");
    if manager is None {
        return;
    }
    user_id = str(uuid.uuid4());
    expired = jwt_encode(
        {"sub": user_id, "exp": datetime.now(UTC) - timedelta(days=1)},
        JWT_SECRET,
        algorithm=JWT_ALGORITHM
    );
    detail = manager.validate_jwt_token_detail(expired);
    assert detail["status"] == "expired";
    assert manager.user_exists(user_id) is False;
}


test "gateway-owned identity is on by default and can be turned off" {
    default_config = normalize_microservices_config({});
    assert default_config["identity"]["gateway_owned"] is True;

    opted_out = normalize_microservices_config({"identity": {"gateway_owned": False}});
    assert opted_out["identity"]["gateway_owned"] is False;
}
