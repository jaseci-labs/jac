"""Tests for the admin portal's opt-in defaults and bootstrap credential policy."""

import os;
import shutil;
import tempfile;
import uuid;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.scale.config.config_loader {
    get_scale_config,
    reset_scale_config,
    resolve_admin_enabled
}
import from jaclang.server.identity.user_manager { UserManager }


def _admin_name -> str {
    return f"admin-{uuid.uuid4().hex[:8]}";
}


test "admin portal is disabled by default" {
    with patch.dict(os.environ, {}, clear=True) {
        reset_scale_config();
        try {
            admin_config = get_scale_config().get_admin_config();
            assert admin_config["enabled"] is False;
        } finally {
            reset_scale_config();
        }
    }
}


test "admin portal ships no default password" {
    with patch.dict(os.environ, {}, clear=True) {
        reset_scale_config();
        try {
            admin_config = get_scale_config().get_admin_config();
            assert admin_config["default_password"] is None;
        } finally {
            reset_scale_config();
        }
    }
}


test "JAC_ADMIN_ENABLED opts the portal in" {
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "true"}, clear=True) {
        reset_scale_config();
        try {
            assert get_scale_config().get_admin_config()["enabled"] is True;
        } finally {
            reset_scale_config();
        }
    }
}


test "JAC_ADMIN_ENABLED accepts on and surrounding whitespace" {
    for raw in ["on", " True ", "YES", "1"] {
        with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": raw}, clear=True) {
            reset_scale_config();
            try {
                assert get_scale_config().get_admin_config()["enabled"] is True;
            } finally {
                reset_scale_config();
            }
        }
    }
}


test "JAC_ADMIN_ENABLED turns the portal off explicitly" {
    for raw in ["off", "false", "0", "no"] {
        with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": raw}, clear=True) {
            reset_scale_config();
            try {
                assert get_scale_config().get_admin_config()["enabled"] is False;
            } finally {
                reset_scale_config();
            }
        }
    }
}


test "an unrecognized JAC_ADMIN_ENABLED warns and stays disabled" {
    with patch.dict(os.environ, {"JAC_ADMIN_ENABLED": "ture"}, clear=True) {
        with patch("logging.getLogger") as get_logger {
            assert not resolve_admin_enabled(True);
            warning = get_logger.return_value.warning;
            assert warning.call_count == 1;
            assert "JAC_ADMIN_ENABLED" in warning.call_args[0][0];
        }
    }
}


test "an unset or empty JAC_ADMIN_ENABLED leaves jac.toml in charge" {
    for env in [{}, {"JAC_ADMIN_ENABLED": ""}, {"JAC_ADMIN_ENABLED": "   "}] {
        with patch.dict(os.environ, env, clear=True) {
            assert resolve_admin_enabled(True);
            assert not resolve_admin_enabled(False);
        }
    }
}


test "JAC_ADMIN_PASSWORD supplies the bootstrap credential" {
    with patch.dict(os.environ, {"JAC_ADMIN_PASSWORD": "s3cret-boot"}, clear=True) {
        reset_scale_config();
        try {
            admin_config = get_scale_config().get_admin_config();
            assert admin_config["default_password"] == "s3cret-boot";
        } finally {
            reset_scale_config();
        }
    }
}


test "bootstrap honors require_password_reset = false" {
    tmp = tempfile.mkdtemp();
    try {
        manager = UserManager(base_path=tmp);
        result = manager.bootstrap_admin_user(
            _admin_name(), "boot-pass-1", require_password_reset=False
        );
        assert "error" not in result;
        user_id = result["user_id"];
        assert manager.is_admin(user_id);
        assert not manager.requires_password_reset(user_id);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "bootstrap_admin reads require_password_reset from jac.toml" {
    import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }

    project_dir = tempfile.mkdtemp();
    username = _admin_name();
    (Path(project_dir) / "jac.toml").write_text(
        "[project]\n"
        'name = "admin-config"\n\n'
        "[scale.admin]\n"
        "enabled = true\n"
        f'username = "{username}"\n'
        'default_password = "boot-pass-1"\n'
        "require_password_reset = false\n"
    );
    with patch.dict(os.environ) {
        os.environ.pop("JAC_ADMIN_ENABLED", None);
        os.environ.pop("JAC_ADMIN_PASSWORD", None);
        reset_scale_config();
        try {
            get_scale_config(project_dir=Path(project_dir));
            manager = UserManager(base_path=project_dir);
            portal = JacAPIServerAdmin(user_manager=manager);
            assert portal.bootstrap_admin();
            user = manager.find_user_by_identity(username);
            assert user is not None;
            assert manager.is_admin(user["user_id"]);
            assert not manager.requires_password_reset(user["user_id"]);
        } finally {
            reset_scale_config();
            shutil.rmtree(project_dir, ignore_errors=True);
        }
    }
}


test "bootstrap refuses to provision an admin without a configured password" {
    tmp = tempfile.mkdtemp();
    try {
        manager = UserManager(base_path=tmp);
        username = _admin_name();
        result = manager.bootstrap_admin_user(username, "");
        assert "error" in result;
        assert "bootstrap password" in result["error"];
        assert manager.find_user_by_identity(username) is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "rotating through update_password clears a pending reset" {
    tmp = tempfile.mkdtemp();
    try {
        manager = UserManager(base_path=tmp);
        result = manager.bootstrap_admin_user(_admin_name(), "boot-pass-1");
        assert "error" not in result;
        user_id = result["user_id"];
        assert manager.requires_password_reset(user_id);

        failed = manager.update_password(user_id, "wrong-pass", "rotated-pass-1");
        assert "error" in failed;
        assert manager.requires_password_reset(user_id);

        rotated = manager.update_password(user_id, "boot-pass-1", "rotated-pass-1");
        assert "error" not in rotated;
        assert not manager.requires_password_reset(user_id);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
