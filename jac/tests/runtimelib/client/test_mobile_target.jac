"""Tests for mobile target registration and discovery."""

import os;
import from pathlib { Path }

# Mobile target modules now ship with core under jaclang/runtimelib/client/.
glob _client_dir = Path(os.path.dirname(__file__)).parent.parent.parent / "jaclang" / "runtimelib" / "client";

test "mobile target files exist" {
    mobile_target_jac = _client_dir / "targets" / "mobile_target.jac";
    mobile_target_impl = _client_dir / "targets" / "impl" / "mobile_target.impl.jac";
    mobile_dir = _client_dir / "targets" / "mobile";

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
    registry_path = _client_dir / "targets" / "registry.jac";
    content = registry_path.read_text();

    assert 'MOBILE = "mobile"' in content;
    assert 'if name_lower == "mobile"' in content;
    assert "return TargetType.MOBILE" in content;
}

test "target factory resolves mobile via registry" {
    impl_path = _client_dir / "targets" / "impl" / "registry.impl.jac";
    register_path = _client_dir / "targets" / "register.jac";
    impl_content = impl_path.read_text();
    register_content = register_path.read_text();

    assert "return self.create(target_type.value, project_dir)" in impl_content;
    assert "registry.get(target_name)" in impl_content;
    assert "registry.register(MobileTarget())" in register_content;
    assert "MobileTarget" in register_content;
}

test "mobile_dev_host helper module exists" {
    decl_path = _client_dir / "mobile_dev_host.jac";
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

test "start exposes mobile dev flags and cli wires cap live-reload" {
    # The mobile dev flags (host/platform) now live on the core `start` command;
    # the client module consumes them natively in run_client_start.
    exec_jac = (
        _client_dir.parent.parent / "cli" / "commands" / "execution.jac"
    ).read_text();
    assert '"host"' in exec_jac;
    assert "Mobile start/dev: android or ios" in exec_jac;
    c = (_client_dir / "cli.jac").read_text();
    assert "JAC_MOBILE_DEV_HOST" in c;
    assert 'os.environ["JAC_MOBILE_PLATFORM"] = str(platform)' in c;
    mobile_impl = (
        _client_dir / "targets" / "impl" / "mobile_target.impl.jac"
    ).read_text();
    mobile_dev = (_client_dir / "targets" / "mobile" / "dev.jac").read_text();
    dev_common = (_client_dir / "targets" / "client_dev_common.jac").read_text();
    mobile = mobile_impl + mobile_dev;
    assert "_run_cap_run_live_reload" in mobile;
    assert "_mobile_start_backend_server" in mobile;
    assert "def _mobile_setup_android_port_reverse" in mobile;
    assert '["adb", "reverse"' in dev_common;
    assert "resolve_mobile_dev_host(plat, host_override)" in mobile_impl;
    assert "resolve_mobile_vite_port(project_dir, port)" in mobile_impl;
    assert "_mobile_setup_android_port_reverse(vite_port, server_port)" in mobile_impl;
    assert 'os.environ.get("JAC_MOBILE_PLATFORM", "auto")' in mobile_dev;
}

test "cli exposes mobile setup platform selector" {
    cli = (_client_dir / "cli.jac").read_text();
    assert "Platform for mobile setup (android, ios, all)" in cli;
    assert "mobile_setup_platform_env_swap" in cli;
    mobile_config = (_client_dir / "targets" / "mobile" / "config.jac").read_text();
    assert "MOBILE_SETUP_PLATFORM_ENV" in mobile_config;
    assert "_resolve_mobile_setup_mode" in mobile_config;
}
