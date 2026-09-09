"""Tests for the admin portal's opt-in defaults and bootstrap credential policy."""

import logging;
import os;
import shutil;
import tempfile;
import uuid;
import from logging.handlers { MemoryHandler }
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.config.config_loader {
    get_scale_config,
    reset_scale_config,
    resolve_admin_enabled
}
import from jaclang.server.identity.user_manager {
    PLACEHOLDER_ADMIN_PASSWORD,
    UserManager
}


def _admin_name -> str {
    return f"admin-{uuid.uuid4().hex[:8]}";
}


def _capture_warnings(fn: any) -> list[str] {
    capture = MemoryHandler(1000);
    root_logger = logging.getLogger();
    root_logger.addHandler(capture);
    try {
        fn();
        return [
            r.getMessage()
            for r in capture.buffer
            if r.levelno >= logging.WARNING
        ];
    } finally {
        root_logger.removeHandler(capture);
    }
}


# Loads the admin section under exactly `env`, leaving no config singleton behind.
def _admin_config(env: dict[str, str]) -> dict[str, any] {
    with patch.dict(os.environ, env, clear=True) {
        reset_scale_config();
        try {
            return get_scale_config().get_admin_config();
        } finally {
            reset_scale_config();
        }
    }
}


def _with_manager(fn: any) {
    tmp = tempfile.mkdtemp();
    try {
        fn(UserManager(base_path=tmp));
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# Runs `fn` against a temp project whose jac.toml carries `admin_section`
# under [scale.admin], with the env overrides out of the way.
def _with_project(admin_section: str, fn: any) {
    project_dir = tempfile.mkdtemp();
    (Path(project_dir) / "jac.toml").write_text(
        '[project]\nname = "admin-config"\n\n[scale.admin]\n' + admin_section
    );
    with patch.dict(os.environ) {
        os.environ.pop("JAC_ADMIN_ENABLED", None);
        os.environ.pop("JAC_ADMIN_PASSWORD", None);
        reset_scale_config();
        try {
            get_scale_config(project_dir=Path(project_dir));
            fn(UserManager(base_path=project_dir));
        } finally {
            reset_scale_config();
            shutil.rmtree(project_dir, ignore_errors=True);
        }
    }
}


def _pending_admin(manager: UserManager) -> str {
    result = manager.bootstrap_admin_user(_admin_name(), "boot-pass-1");
    assert "error" not in result;
    user_id = result["user_id"];
    assert manager.requires_password_reset(user_id);
    return user_id;
}


test "admin portal ships disabled with no default password" {
    admin_config = _admin_config({});
    assert admin_config["enabled"] is False;
    assert admin_config["default_password"] is None;
}


test "the env overrides reach get_admin_config" {
    admin_config = _admin_config(
        {"JAC_ADMIN_ENABLED": "true", "JAC_ADMIN_PASSWORD": "s3cret-boot"}
    );
    assert admin_config["enabled"] is True;
    assert admin_config["default_password"] == "s3cret-boot";
}


test "JAC_ADMIN_ENABLED is a tri-state override of jac.toml" {
    for (env, forced) in [
        ({}, None),
        ({"JAC_ADMIN_ENABLED": ""}, None),
        ({"JAC_ADMIN_ENABLED": "   "}, None),
        ({"JAC_ADMIN_ENABLED": "true"}, True),
        ({"JAC_ADMIN_ENABLED": "on"}, True),
        ({"JAC_ADMIN_ENABLED": " True "}, True),
        ({"JAC_ADMIN_ENABLED": "YES"}, True),
        ({"JAC_ADMIN_ENABLED": "1"}, True),
        ({"JAC_ADMIN_ENABLED": "false"}, False),
        ({"JAC_ADMIN_ENABLED": "off"}, False),
        ({"JAC_ADMIN_ENABLED": "no"}, False),
        ({"JAC_ADMIN_ENABLED": "0"}, False)
    ] {
        with patch.dict(os.environ, env, clear=True) {
            for configured in [True, False] {
                expected = configured if forced is None else forced;
                assert resolve_admin_enabled(configured) is expected , env;
            }
        }
    }
}


test "an unrecognized JAC_ADMIN_ENABLED warns once and stays disabled" {
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "ture"}, clear=True) {
        def attempt {
            assert not resolve_admin_enabled(True);
        }
        seen = _capture_warnings(attempt);
        assert len(
            [
                m
                for m in seen
                if "JAC_ADMIN_ENABLED" in m and "ture" in m
            ]
        )
            == 1 , seen;
    }
}


test "bootstrap honors require_password_reset = false" {
    def check(manager: UserManager) {
        result = manager.bootstrap_admin_user(
            _admin_name(), "boot-pass-1", require_password_reset=False
        );
        assert "error" not in result;
        assert manager.is_admin(result["user_id"]);
        assert not manager.requires_password_reset(result["user_id"]);
    }
    _with_manager(check);
}


test "bootstrap refuses an absent or placeholder password" {
    def check(manager: UserManager) {
        for (password, reason) in [
            ("", "bootstrap password"),
            (PLACEHOLDER_ADMIN_PASSWORD, PLACEHOLDER_ADMIN_PASSWORD)
        ] {
            username = _admin_name();
            result = manager.bootstrap_admin_user(username, password);
            assert "error" in result and reason in result["error"] , result;
            assert manager.find_user_by_identity(username) is None;
        }
    }
    _with_manager(check);
}


test "bootstrap_admin reads require_password_reset from jac.toml" {
    username = _admin_name();
    def check(manager: UserManager) {
        assert JacAPIServerAdmin(user_manager=manager).bootstrap_admin();
        user = manager.find_user_by_identity(username);
        assert user is not None;
        assert manager.is_admin(user["user_id"]);
        assert not manager.requires_password_reset(user["user_id"]);
    }
    _with_project(
        "enabled = true\n"
        f'username = "{username}"\n'
        'default_password = "boot-pass-1"\n'
        "require_password_reset = false\n",
        check
    );
}


test "a disabled portal warns when an admin account is dormant in the identity store" {
    username = _admin_name();
    def check(manager: UserManager) {
        portal = JacAPIServerAdmin(user_manager=manager);
        def register {
            assert not portal.register_admin_endpoints();
        }
        assert not [
            m
            for m in _capture_warnings(register)
            if username in m
        ];
        assert "error" not in manager.bootstrap_admin_user(username, "boot-pass-1");
        dormant = [
            m
            for m in _capture_warnings(register)
            if username in m
        ];
        assert len(dormant) == 1 , dormant;
    }
    _with_project("enabled = false\n" f'username = "{username}"\n', check);
}


test "a disabled portal still registers when the identity store is unreachable" {
    def check(manager: UserManager) {
        portal = JacAPIServerAdmin(user_manager=manager);
        with patch.object(
            manager,
            "find_user_by_identity",
            side_effect=RuntimeError("connection refused")
        ) {
            assert portal.register_admin_endpoints() is False;
        }
    }
    _with_project("enabled = false\n", check);
}


test "rotating through update_password clears a pending reset only on success" {
    def check(manager: UserManager) {
        user_id = _pending_admin(manager);
        assert "error"
            in manager.update_password(user_id, "wrong-pass", "rotated-pass-1");
        assert manager.requires_password_reset(user_id);
        assert "error"
            not in manager.update_password(user_id, "boot-pass-1", "rotated-pass-1");
        assert not manager.requires_password_reset(user_id);
    }
    _with_manager(check);
}


test "recovering through reset_password_by_user_id clears a pending reset only on success" {
    def check(manager: UserManager) {
        user_id = _pending_admin(manager);
        assert "error"
            in manager.reset_password_by_user_id("no-such-user", "recovered-pass-1");
        assert manager.requires_password_reset(user_id);
        assert "error"
            not in manager.reset_password_by_user_id(user_id, "recovered-pass-1");
        assert not manager.requires_password_reset(user_id);
        assert manager.authenticate(
            manager.get_username(user_id) or "", "recovered-pass-1"
        )
            is not None;
    }
    _with_manager(check);
}
