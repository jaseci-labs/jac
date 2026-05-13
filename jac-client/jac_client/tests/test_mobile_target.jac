"""Tests for mobile target registration and discovery."""

import os;
import from pathlib { Path }

glob _plugin_dir = Path(os.path.dirname(__file__)).parent / "plugin";

test "mobile target files exist" {
    mobile_target_jac = _plugin_dir / "src" / "targets" / "mobile_target.jac";
    mobile_target_impl = (
        _plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    );
    mobile_dir = _plugin_dir / "src" / "targets" / "mobile";

    assert mobile_target_jac.exists() , (
        f"mobile_target.jac not found at {mobile_target_jac}"
    );
    assert mobile_target_impl.exists() , (
        f"mobile_target.impl.jac not found at {mobile_target_impl}"
    );
    assert mobile_dir.is_dir();
    assert (mobile_dir / "common.jac").exists();
    assert (mobile_dir / "deps.jac").exists();
    assert (mobile_dir / "config.jac").exists();
    assert (mobile_dir / "scaffold.jac").exists();
    assert (mobile_dir / "bundle.jac").exists();
    assert (mobile_dir / "dev.jac").exists();

    mobile_content = mobile_target_jac.read_text();
    assert "obj MobileTarget" in mobile_content;
    assert "def setup" in mobile_content;
    assert "def build" in mobile_content;
    assert "def dev" in mobile_content;
    assert "def start" in mobile_content;
}

test "target type parser supports mobile" {
    registry_path = _plugin_dir / "src" / "targets" / "registry.jac";
    content = registry_path.read_text();

    assert 'MOBILE = "mobile"' in content;
    assert 'if name_lower == "mobile"' in content;
    assert "return TargetType.MOBILE" in content;
}

test "target factory supports mobile target" {
    impl_path = _plugin_dir / "src" / "targets" / "impl" / "registry.impl.jac";
    content = impl_path.read_text();

    assert "elif target_type == TargetType.MOBILE" in content;
    assert "MobileTarget" in content;
    assert "TargetType.MOBILE" in content;
}

test "mobile_dev_host helper module exists" {
    decl_path = _plugin_dir / "src" / "mobile_dev_host.jac";
    assert decl_path.exists();
    d = decl_path.read_text();
    assert "def detect_lan_ipv4" in d;
    assert "def resolve_mobile_dev_host" in d;
    assert "def resolve_mobile_vite_port" in d;
    assert "def is_android_emulator_adb" in d;
    assert "def is_ios_simulator" in d;
    assert "10.0.2.2" in d;
    assert "JAC_MOBILE_VITE_PORT" in d;
    assert "8.8.8.8" in d;
}

test "JacCmd create_cmd has hookimpl on create_cmd" {
    # Regression: @hookimpl must decorate static def create_cmd (not a docstring).
    # Otherwise pluggy never registers the hook, extend_command never runs, and
    # jac setup / jac build / jac start client integration silently no-op.
    cli = (_plugin_dir / "cli.jac").read_text().replace("\r\n", "\n");
    assert "@hookimpl\n    static def create_cmd" in cli;
}

test "cli exposes mobile dev flags and cap live-reload" {
    cli = _plugin_dir / "cli.jac";
    c = cli.read_text();
    assert 'Arg.create(\n                        "host"' in c;
    assert "Mobile start/dev: android or ios" in c;
    assert "JAC_MOBILE_DEV_HOST" in c;
    assert 'ctx.get_arg("platform", "auto")' in c;
    mobile_impl = (
        _plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    ).read_text();
    mobile_dev = (_plugin_dir / "src" / "targets" / "mobile" / "dev.jac").read_text();
    mobile = mobile_impl + mobile_dev;
    assert "--live-reload" in mobile;
    assert "_mobile_start_backend_server" in mobile;
    assert "def _mobile_setup_android_port_reverse" in mobile;
    assert '["adb", "reverse"' in mobile;
    assert "resolve_mobile_dev_host(plat, host_override)" in mobile_impl;
    assert "resolve_mobile_vite_port(project_dir, port)" in mobile_impl;
    assert "_mobile_setup_android_port_reverse(vite_port, server_port)" in mobile_impl;
    assert 'os.environ.get("JAC_MOBILE_PLATFORM", "auto")' in mobile_dev;
}

test "cli exposes mobile setup platform selector" {
    cli = (_plugin_dir / "cli.jac").read_text();
    assert "Platform for mobile setup (android, ios, all)" in cli;
    assert "JAC_MOBILE_SETUP_PLATFORM" in cli;
    mobile_config = (
        _plugin_dir / "src" / "targets" / "mobile" / "config.jac"
    ).read_text();
    assert "MOBILE_SETUP_PLATFORM_ENV" in mobile_config;
    assert "_resolve_mobile_setup_mode" in mobile_config;
}
